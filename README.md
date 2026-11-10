# Flashot

Chụp màn hình nhanh cho macOS, kiểu công cụ chụp của Zalo. Swift (AppKit + ScreenCaptureKit)
cho giao diện, Rust (`core/`) cho xử lý điểm ảnh (làm mờ ô vuông, làm nhòe).

## Dùng

| Phím | Việc |
|---|---|
| ⌥⇧S | Chụp vùng: kéo để chọn, hoặc bấm một lần để lấy cửa sổ dưới con trỏ |
| ⌘⇧1 | Chụp toàn màn hình (vẫn vẽ được trước khi chép) |
| R E A P T N M B | Chữ nhật, elip, mũi tên, bút, chữ, đánh số, làm mờ ô vuông, làm nhòe |
| Enter / ⌘C / bấm đúp | Chép vào bộ nhớ tạm |
| ⌘S | Lưu vào `~/Pictures/Flashot` |
| ⌘P | Ghim ảnh nổi trên màn hình (cuộn để phóng to, bấm đúp hoặc Esc để đóng) |
| ⌘Z | Hoàn tác |
| Chuột phải | Chọn lại vùng (khi chưa vẽ gì) / huỷ |
| Esc | Huỷ |

Kéo vùng chọn để di chuyển, kéo cạnh/góc để đổi kích thước.

## Build

```sh
./build.sh          # build/Flashot.app
open build/Flashot.app
```

Cần Rust (cargo) và Xcode Command Line Tools. Lần đầu macOS hỏi quyền **Ghi màn hình**;
cấp quyền rồi mở lại app.
