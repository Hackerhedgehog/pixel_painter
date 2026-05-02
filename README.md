# Pixel Painter

A Flutter drawing application with a full-featured canvas and tool panel. Create drawings using brushes, shapes, fill, spray, and eraser tools, then save them as PNG.

## Features

- **Drawing tools** — Brush, line, rectangle, ellipse, fill (flood fill), spray, and eraser
- **Color picker** — 20 preset colors
- **Size control** — Continuous 1–100 slider with numeric input for each tool
- **Undo / Redo** — Up to 20 steps in each direction
- **Zoom and pan** — Scroll wheel to zoom, pinch on touch, middle-mouse drag to pan
- **Canvas size** — Configurable width and height (100–4000 px), default 800 × 600
- **Clear all** — Erase the canvas with a confirmation prompt
- **Save** — Export the drawing as PNG (platform-dependent destination)

### Supported Platforms

| Platform | Save location |
|----------|--------------|
| Android | Gallery — `Pictures/PixelPainter` |
| iOS | Photo library |
| Web | Browser download |
| Linux / Windows / macOS | App documents directory |

---

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.9.2 or later
- Dart SDK 3.9.2 or later

### Installation

```bash
flutter pub get
flutter run
```

Specify a target device:

```bash
flutter run -d chrome      # Web
flutter run -d linux       # Linux desktop
flutter run -d android     # Android device/emulator
flutter run -d ios         # iOS simulator (macOS only)
```

### Platform Notes

**Android** — Required permissions are already set in `AndroidManifest.xml`. `requestLegacyExternalStorage` is included for Android 10 gallery access.

**iOS** — `NSPhotoLibraryAddUsageDescription` and `NSPhotoLibraryUsageDescription` are already in `ios/Runner/Info.plist`. iOS will prompt for photo library access on the first save.

**Web** — No extra configuration needed.

---

## UI Layout

```
┌─────────────────────────────────────────┐
│ AppBar  (☰ menu  |  Pixel Painter)      │
├──────┬──────────────────────────────────┤
│Side  │ TopToolBar                       │
│Panel │  undo · redo · color · size      │
│      ├──────────────────────────────────┤
│Canvas│                                  │
│Width │        Drawing Canvas            │
│Height│    (zoom / pan / draw here)      │
│      │                                  │
│Save  ├──────────────────────────────────┤
│Clear │ ToolPanel  (tool selector)       │
└──────┴──────────────────────────────────┘
```

- **Side panel** — Toggle with the ☰ button. Contains canvas size fields, Save, and Clear All.
- **Top toolbar** — Undo, Redo, color swatch, and size slider (hidden for Fill tool).
- **Tool panel** — Bottom row for selecting the active drawing tool.

---

## Drawing Tools

| Tool | How to use |
|------|-----------|
| **Brush** | Drag to draw freehand strokes |
| **Line** | Drag from start to end point |
| **Rectangle** | Drag to define opposite corners; hold 1:1 to force a square |
| **Ellipse** | Drag to define bounding box; hold 1:1 to force a circle |
| **Fill** | Tap to flood-fill all connected pixels of the same color |
| **Spray** | Drag to airbrush; slower movement = denser coverage |
| **Eraser** | Drag to erase strokes back to white |

### Size slider

The 1–100 slider in the top toolbar maps to:

| Tool | What it controls |
|------|-----------------|
| Brush, Eraser | Stroke width |
| Line, Rectangle, Ellipse | Outline width |
| Spray | Spray radius |
| Fill | — (no size) |

### Aspect-ratio lock (Rectangle / Ellipse)

When Rectangle or Ellipse is active, a lock button appears in the top toolbar. Tap it to constrain the shape to a 1:1 ratio (square or circle).

---

## Zoom and Pan

| Action | Gesture |
|--------|---------|
| Zoom in / out | Scroll wheel (desktop) or pinch (touch) |
| Pan | Middle-mouse drag (desktop) or two-finger drag (touch) |

Zoom and pan gestures are independent from drawing. Single-finger drawing still works normally while zoomed in.

---

## Keyboard / Mouse Shortcuts

| Action | Shortcut |
|--------|---------|
| Undo | Ctrl + Z (via toolbar button) |
| Redo | Ctrl + Y (via toolbar button) |

---

## Running Tests

```bash
flutter test
```
