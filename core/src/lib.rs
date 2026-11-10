//! Pixel work for Flashot: the mosaic and blur used to hide parts of a screenshot.
//! Buffers are 8-bit RGBA (any channel order), rows top-down, `stride` bytes per row.

/// A rectangle clamped to the image, or `None` when nothing of it is inside.
fn clamp(width: usize, height: usize, x: usize, y: usize, w: usize, h: usize) -> Option<(usize, usize, usize, usize)> {
    let x1 = x.saturating_add(w).min(width);
    let y1 = y.saturating_add(h).min(height);
    (x < x1 && y < y1).then_some((x, y, x1, y1))
}

/// Replaces each `block`×`block` cell of the rectangle with its average color.
pub fn pixelate(buf: &mut [u8], width: usize, height: usize, stride: usize, rect: (usize, usize, usize, usize), block: usize) {
    let Some((x0, y0, x1, y1)) = clamp(width, height, rect.0, rect.1, rect.2, rect.3) else { return };
    let block = block.max(1);
    for by in (y0..y1).step_by(block) {
        let by1 = (by + block).min(y1);
        for bx in (x0..x1).step_by(block) {
            let bx1 = (bx + block).min(x1);
            let mut sum = [0u64; 4];
            for y in by..by1 {
                let row = &buf[y * stride + bx * 4..y * stride + bx1 * 4];
                for px in row.chunks_exact(4) {
                    for c in 0..4 {
                        sum[c] += px[c] as u64;
                    }
                }
            }
            let n = ((by1 - by) * (bx1 - bx)) as u64;
            let avg = sum.map(|s| ((s + n / 2) / n) as u8);
            for y in by..by1 {
                for px in buf[y * stride + bx * 4..y * stride + bx1 * 4].chunks_exact_mut(4) {
                    px.copy_from_slice(&avg);
                }
            }
        }
    }
}

/// Three box-blur passes in each direction, close to a Gaussian of the given radius.
pub fn blur(buf: &mut [u8], width: usize, height: usize, stride: usize, rect: (usize, usize, usize, usize), radius: usize) {
    let Some((x0, y0, x1, y1)) = clamp(width, height, rect.0, rect.1, rect.2, rect.3) else { return };
    if radius == 0 {
        return;
    }
    let (w, h) = (x1 - x0, y1 - y0);
    let mut line = vec![[0u8; 4]; w.max(h)];
    for _ in 0..3 {
        for y in y0..y1 {
            for (i, px) in line[..w].iter_mut().enumerate() {
                let o = y * stride + (x0 + i) * 4;
                px.copy_from_slice(&buf[o..o + 4]);
            }
            box_line(&line[..w], radius, |i, px| {
                let o = y * stride + (x0 + i) * 4;
                buf[o..o + 4].copy_from_slice(&px);
            });
        }
        for x in x0..x1 {
            for (i, px) in line[..h].iter_mut().enumerate() {
                let o = (y0 + i) * stride + x * 4;
                px.copy_from_slice(&buf[o..o + 4]);
            }
            box_line(&line[..h], radius, |i, px| {
                let o = (y0 + i) * stride + x * 4;
                buf[o..o + 4].copy_from_slice(&px);
            });
        }
    }
}

/// Running-sum box filter over one row or column; edges repeat the border pixel.
fn box_line(src: &[[u8; 4]], radius: usize, mut out: impl FnMut(usize, [u8; 4])) {
    let n = src.len();
    let at = |i: isize| src[i.clamp(0, n as isize - 1) as usize];
    let r = radius as isize;
    let window = (2 * r + 1) as u32;
    let mut sum = [0u32; 4];
    for i in -r..=r {
        let px = at(i);
        for c in 0..4 {
            sum[c] += px[c] as u32;
        }
    }
    for i in 0..n as isize {
        out(i as usize, sum.map(|s| ((s + window / 2) / window) as u8));
        let (add, sub) = (at(i + r + 1), at(i - r));
        for c in 0..4 {
            sum[c] = sum[c] + add[c] as u32 - sub[c] as u32;
        }
    }
}

/// # Safety
/// `rgba` must point to `stride * height` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn shot_pixelate(
    rgba: *mut u8, width: usize, height: usize, stride: usize,
    x: usize, y: usize, w: usize, h: usize, block: usize,
) {
    if rgba.is_null() || stride < width * 4 {
        return;
    }
    let buf = std::slice::from_raw_parts_mut(rgba, stride * height);
    pixelate(buf, width, height, stride, (x, y, w, h), block);
}

/// # Safety
/// `rgba` must point to `stride * height` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn shot_blur(
    rgba: *mut u8, width: usize, height: usize, stride: usize,
    x: usize, y: usize, w: usize, h: usize, radius: usize,
) {
    if rgba.is_null() || stride < width * 4 {
        return;
    }
    let buf = std::slice::from_raw_parts_mut(rgba, stride * height);
    blur(buf, width, height, stride, (x, y, w, h), radius);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn image(w: usize, h: usize) -> Vec<u8> {
        (0..w * h).flat_map(|i| [(i * 7 % 256) as u8, (i * 13 % 256) as u8, (i % 256) as u8, 255]).collect()
    }

    #[test]
    fn pixelate_makes_each_block_one_color() {
        let (w, h) = (10, 10);
        let mut buf = image(w, h);
        pixelate(&mut buf, w, h, w * 4, (0, 0, 10, 10), 5);
        for (bx, by) in [(0, 0), (5, 0), (0, 5), (5, 5)] {
            let first = &buf[(by * w + bx) * 4..(by * w + bx) * 4 + 4].to_vec();
            for y in by..by + 5 {
                for x in bx..bx + 5 {
                    assert_eq!(&buf[(y * w + x) * 4..(y * w + x) * 4 + 4], &first[..]);
                }
            }
        }
    }

    #[test]
    fn pixelate_leaves_outside_alone_and_clamps() {
        let (w, h) = (8, 8);
        let original = image(w, h);
        let mut buf = original.clone();
        pixelate(&mut buf, w, h, w * 4, (4, 4, 100, 100), 3);
        assert_eq!(buf[..4 * w * 4], original[..4 * w * 4]);
        assert_ne!(buf, original);
        pixelate(&mut buf, w, h, w * 4, (50, 50, 5, 5), 3); // fully outside: no panic
    }

    #[test]
    fn blur_keeps_flat_color_and_smooths_edges() {
        let (w, h) = (6, 1);
        let mut flat = [9u8, 9, 9, 255].repeat(w);
        blur(&mut flat, w, h, w * 4, (0, 0, w, h), 2);
        assert!(flat.chunks(4).all(|p| p == [9, 9, 9, 255]));

        let mut edge: Vec<u8> = (0..w).flat_map(|i| if i < 3 { [0, 0, 0, 255] } else { [255, 255, 255, 255] }).collect();
        blur(&mut edge, w, h, w * 4, (0, 0, w, h), 1);
        assert!(edge[2 * 4] > 0 && edge[3 * 4] < 255);
    }

    #[test]
    fn respects_stride_padding() {
        let (w, h, stride) = (2, 2, 12);
        let mut buf = vec![7u8; stride * h];
        unsafe { shot_pixelate(buf.as_mut_ptr(), w, h, stride, 0, 0, 2, 2, 2) };
        assert_eq!(&buf[8..12], &[7, 7, 7, 7]); // padding untouched
    }
}
