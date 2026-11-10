# Flashot

A fast screenshot tool for macOS, in the spirit of Zalo's capture tool: pick a region,
mark it up, and copy, save, or pin it.

Press **⌥⇧S**, drag over part of the screen (or click once to take the window under the
pointer), draw on it, and press **Enter**. The image is now in your clipboard.

## Features

- Region capture with window snapping; move the selection or pull its edges to resize.
- Full-screen capture with **⌘⇧1**, still editable before copying.
- Drawing tools: rectangle, ellipse, arrow, pen, text, numbered markers, mosaic and blur,
  with seven colors and three sizes.
- Copy, save to `~/Pictures/Flashot`, or pin the shot as a floating window.
- A main window with recent shots, history, and settings: rebindable shortcuts, save folder,
  auto-save on copy, launch at login.

## Shortcuts while capturing

| Key | Action |
|---|---|
| R E A P | Rectangle, ellipse, arrow, pen |
| T N | Text, numbered marker |
| M B | Mosaic, blur |
| Enter / ⌘C / double-click | Copy to clipboard |
| ⌘S | Save |
| ⌘P | Pin on screen (scroll to zoom, double-click or Esc to close) |
| ⌘Z | Undo |
| ⌘A | Select the whole screen |
| Right-click | Pick a new region (before drawing) / cancel |
| Esc | Cancel |

## Install

Download the DMG from [Releases](https://github.com/thanhphu2643/Flashot/releases), open it,
and drag Flashot to Applications. Requires an Apple Silicon Mac and macOS 14 or later.

The build isn't notarized, so macOS blocks it the first time: try to open it, then go to
System Settings → Privacy & Security and choose **Open Anyway**. Grant **Screen Recording**
permission when asked, then reopen the app.

## Build

Requires Xcode Command Line Tools and Rust.

```sh
./build.sh          # build/Flashot.app
./dmg.sh            # build/Flashot-<version>.dmg
open build/Flashot.app
```

`swift scripts/make-icon.swift` redraws the app icon.

## How it works

The app is Swift (AppKit, SwiftUI, ScreenCaptureKit). Pixel work for the mosaic and blur
tools lives in a small Rust static library in `core/`, called through a C header in
`Sources/CShotCore`.

## License

[MIT](LICENSE)
