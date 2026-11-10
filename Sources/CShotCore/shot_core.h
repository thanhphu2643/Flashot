#pragma once
#include <stddef.h>

// 8-bit RGBA buffers, rows top-down, `stride` bytes per row. Rectangles are in pixels and
// are clamped to the image.

/// Replaces each `block`x`block` cell of the rectangle with its average color.
void shot_pixelate(unsigned char *rgba, size_t width, size_t height, size_t stride,
                   size_t x, size_t y, size_t w, size_t h, size_t block);
/// Gaussian-like blur (three box passes) of the rectangle.
void shot_blur(unsigned char *rgba, size_t width, size_t height, size_t stride,
               size_t x, size_t y, size_t w, size_t h, size_t radius);
