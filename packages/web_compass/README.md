# web_compass

A clean, modern Flutter Web package to read absolute and relative device orientation (compass) sensors.

## Features

- **Absolute Orientation**: Reads true North compass directions (`deviceorientationabsolute`) on supported devices.
- **Dual-Listener Fallback**: Automatically falls back to relative direction listening if absolute orientation is unavailable or unsupported on the browser, keeping the compass interactive.
- **iOS Permission Handler**: Handles iOS-specific `DeviceOrientationEvent.requestPermission` API cleanly from Dart.
- **Modern JS Interop**: Built using Dart's new JS interop bindings (`package:web`) instead of legacy `dart:js`.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  web_compass: ^1.0.0
```

## Usage Example

```dart
import 'package:web_compass/web_compass.dart';

// 1. Request permission (required on iOS before listening)
final granted = await WebCompass.requestPermission();
if (granted) {
  // 2. Listen to orientation changes
  WebCompass.onOrientationChanged.listen((event) {
    print('Heading: ${event.heading}');
    print('Pitch (Tilt): ${event.pitch}');
    print('Roll: ${event.roll}');
  });
}
```
