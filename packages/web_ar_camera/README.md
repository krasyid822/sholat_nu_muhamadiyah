# web_ar_camera

A clean, modern Flutter Web package to stream and display the environment-facing (back) camera feed as a background view. Perfect for building augmented reality overlays.

## Features

- **Back Camera Stream**: Requests and streams environment-facing feed via browser `getUserMedia`.
- **Dynamic Platform View**: Spawns and manages native HTML `<video>` elements dynamically inside `HtmlElementView`.
- **Resource Disposal**: Automatically releases camera stream tracks when the widget is disposed.
- **Modern JS Interop**: Written using Dart's new JS interop bindings (`package:web`).

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  web_ar_camera: ^1.0.0
```

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:web_ar_camera/web_ar_camera.dart';

class MyArScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The camera background view
          const Positioned.fill(
            child: WebArCameraView(),
          ),
          // 2. Your AR overlays
          Center(
            child: Text(
              'Virtual Content',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }
}
```
