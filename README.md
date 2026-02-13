# Pixel Painter

A Flutter drawing application with a full-featured canvas and tool panel. Create drawings using brushes, shapes, fill, spray, and eraser tools, then save them to local storage or the device gallery.

## Project Overview

Pixel Painter is a cross-platform drawing app built with Flutter. It provides:

- **Canvas** – White drawing surface that maximizes available screen space
- **Drawing tools** – Brush, line, rectangle, ellipse, fill, spray, and eraser
- **Color picker** – Choose from predefined colors for strokes and fills
- **Size options** – Adjustable brush, outline, and spray sizes
- **Undo** – Revert up to 5 previous actions
- **Save** – Export drawings as PNG (gallery on mobile, documents on desktop, download on web)

### Supported Platforms

- **Android** – Saves to gallery folder `Pictures/PixelPainter`
- **iOS** – Saves to photo library
- **Web** – Triggers PNG download
- **Linux / Windows / macOS** – Saves to app documents directory

---

## Setup Instructions

You may download and intall the [android APK](https://drive.google.com/file/d/1qc-gIX2ZnsuSKWuyrrnfxgl4OIIr8oEz/view?usp=sharing) or [Linux app](https://drive.google.com/file/d/1OkohhqmuFPAYvrGof6gLHsCT2a0Byz9d/view?usp=sharing). No setup required.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.9.2 or later)
- Dart SDK 3.9.2 or later

### Installation

1. **Clone the repository** (or navigate to the project directory):

    ```bash
    cd pixelPainter
    ```

2. **Install dependencies**:

    ```bash
    flutter pub get
    ```

3. **Run the app**:

    ```bash
    flutter run
    ```

    Or specify a device:

    ```bash
    flutter run -d chrome      # Web
    flutter run -d linux       # Linux desktop
    flutter run -d android     # Android device/emulator
    flutter run -d ios         # iOS simulator (macOS only)
    ```

### Platform-Specific Configuration

#### Android

The project includes the required permissions in `AndroidManifest.xml`. For Android 10, `requestLegacyExternalStorage` is set to allow gallery access. No extra setup is needed.

#### iOS

Add these keys to `ios/Runner/Info.plist` (already included in this project):

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Pixel Painter needs permission to save your drawings to the photo library.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pixel Painter needs permission to save your drawings to the photo library.</string>
```

On first save, iOS will prompt for photo library access.

#### Web

No additional configuration. The app uses `package:web` for file downloads.

---

## Usage Guide

### Tool Panel

The tool panel at the bottom of the screen contains:

| Section   | Description                                             |
| --------- | ------------------------------------------------------- |
| **Undo**  | Reverts the last action (up to 5 steps)                 |
| **Save**  | Saves the drawing (platform-dependent destination)      |
| **Color** | Opens the color picker; tap to choose stroke/fill color |

### Drawing Tools

1. **Brush** – Freehand drawing
    - Select Brush, choose color and size (4 or 12)
    - Draw by dragging on the canvas

2. **Line** – Straight lines
    - Select Line, choose color and outline width (2 or 6)
    - Drag from start to end point

3. **Rectangle** – Rectangles (including squares)
    - Select Rect, choose color and outline width
    - Drag to define opposite corners

4. **Ellipse** – Ellipses (including circles)
    - Select Ellipse, choose color and outline width
    - Drag to define the bounding box

5. **Fill** – Flood fill
    - Select Fill, choose color
    - Tap inside a region to fill it with the selected color

6. **Spray** – Airbrush effect
    - Select Spray, choose color and size (8 or 24)
    - Drag to spray; more density where you move slowly

7. **Eraser** – Restore to white
    - Select Eraser, choose size
    - Drag to erase (restores canvas default color)

### Size Options

When a tool with size options is selected, the panel shows:

- **Brush size** – For Brush and Eraser (4 or 12)
- **Outline** – For Line, Rectangle, Ellipse (2 or 6)
- **Spray size** – For Spray (8 or 24)

### Workflow Tips

- Use **Undo** to correct mistakes (up to 5 actions)
- Use **Fill** on empty areas to fill the whole canvas
- Use **Eraser** to remove strokes and restore white
- **Save** exports the current canvas as a PNG file

### Saving

- **Mobile (Android/iOS)**: Drawings are saved to the gallery in `Pictures/PixelPainter`
- **Desktop (Linux, Windows, macOS)**: Drawings are saved to the app documents directory
- **Web**: A PNG file is downloaded to the browser’s default download location
