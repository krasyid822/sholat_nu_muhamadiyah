import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

class CompassEvent {
  final double heading;
  final double pitch;
  final double roll;
  final bool isAbsolute;

  CompassEvent({
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.isAbsolute,
  });

  @override
  String toString() {
    return 'CompassEvent(heading: ${heading.toStringAsFixed(1)}, pitch: ${pitch.toStringAsFixed(1)}, roll: ${roll.toStringAsFixed(1)}, absolute: $isAbsolute)';
  }
}

@JS('DeviceOrientationEvent')
extension type DeviceOrientationEventPermissionExtension(web.DeviceOrientationEvent _) {
  external static JSPromise<JSString>? requestPermission();
}

@JS()
extension type DeviceOrientationEventExtension(web.DeviceOrientationEvent _) {
  @JS('webkitCompassHeading')
  external double? get webkitCompassHeading;
}

class WebCompass {
  static StreamController<CompassEvent>? _controller;
  static bool _hasAbsoluteEvent = false;

  /// Check if the browser supports DeviceOrientationEvent
  static bool get isSupported {
    final windowObject = web.window as JSObject;
    return windowObject.has('DeviceOrientationEvent');
  }

  /// Request permission for device orientation sensors (specifically for iOS)
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;

    final windowObject = web.window as JSObject;
    if (windowObject.has('DeviceOrientationEvent')) {
      final deviceOrientationEvent = windowObject.getProperty<JSObject>('DeviceOrientationEvent'.toJS);
      if (deviceOrientationEvent.has('requestPermission')) {
        try {
          final promise = DeviceOrientationEventPermissionExtension.requestPermission();
          if (promise != null) {
            final JSString result = await promise.toDart;
            return result.toDart == 'granted';
          }
        } catch (e) {
          web.console.error('Orientation permission request error: $e'.toJS);
          return true;
        }
      }
    }
    return true;
  }

  /// Listen to compass/orientation events
  static Stream<CompassEvent> get onOrientationChanged {
    if (_controller != null) {
      return _controller!.stream;
    }

    _controller = StreamController<CompassEvent>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );

    return _controller!.stream;
  }

  static void _startListening() {
    _hasAbsoluteEvent = false;

    // Listen to BOTH absolute and relative events
    web.window.addEventListener('deviceorientationabsolute', _handleAbsoluteEvent.toJS);
    web.window.addEventListener('deviceorientation', _handleRelativeEvent.toJS);
  }

  static void _stopListening() {
    web.window.removeEventListener('deviceorientationabsolute', _handleAbsoluteEvent.toJS);
    web.window.removeEventListener('deviceorientation', _handleRelativeEvent.toJS);
    _controller = null;
  }

  static void _handleAbsoluteEvent(web.Event event) {
    if (!event.isA<web.DeviceOrientationEvent>()) return;
    _hasAbsoluteEvent = true;
    _processEvent(event as web.DeviceOrientationEvent, isAbsolute: true);
  }

  static void _handleRelativeEvent(web.Event event) {
    if (!event.isA<web.DeviceOrientationEvent>()) return;
    if (_hasAbsoluteEvent) return;
    _processEvent(event as web.DeviceOrientationEvent, isAbsolute: false);
  }

  static void _processEvent(web.DeviceOrientationEvent event, {required bool isAbsolute}) {
    double? heading;

    // Use non-standard webkitCompassHeading on iOS if available
    final extension = DeviceOrientationEventExtension(event);
    final webkitHeading = extension.webkitCompassHeading;
    
    if (webkitHeading != null) {
      heading = webkitHeading;
    } else if (event.alpha != null) {
      // standard alpha increases counter-clockwise, compass heading increases clockwise.
      heading = (360.0 - event.alpha!) % 360.0;
    }

    if (heading == null) return;

    final pitch = event.beta ?? 0.0;
    final roll = event.gamma ?? 0.0;

    _controller?.add(
      CompassEvent(
        heading: heading,
        pitch: pitch,
        roll: roll,
        isAbsolute: isAbsolute,
      ),
    );
  }
}
