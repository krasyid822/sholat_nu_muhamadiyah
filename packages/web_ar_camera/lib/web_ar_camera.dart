import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class WebArCameraView extends StatefulWidget {
  final Function(String? error)? onError;
  final Function()? onStarted;

  const WebArCameraView({
    super.key,
    this.onError,
    this.onStarted,
  });

  @override
  State<WebArCameraView> createState() => _WebArCameraViewState();
}

class _WebArCameraViewState extends State<WebArCameraView> {
  static const String _viewType = 'web-ar-camera-view';
  static bool _factoryRegistered = false;
  
  static final Map<int, web.HTMLVideoElement> _videoElements = {};
  static final Map<int, web.MediaStream> _streams = {};

  int? _currentViewId;

  @override
  void initState() {
    super.initState();
    if (!_factoryRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final video = web.document.createElement('video') as web.HTMLVideoElement;
        video.autoplay = true;
        video.muted = true;
        video.setAttribute('playsinline', 'true');
        video.style.position = 'absolute';
        video.style.width = '100%';
        video.style.height = '100%';
        video.style.objectFit = 'cover';
        video.style.backgroundColor = '#000000';
        _videoElements[viewId] = video;
        return video;
      });
      _factoryRegistered = true;
    }
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _startCamera(int viewId) async {
    final video = _videoElements[viewId];
    if (video == null) return;

    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      final constraints = web.MediaStreamConstraints(
        video: {
          'facingMode': {'ideal': 'environment'}
        }.jsify()!,
        audio: false.jsify()!,
      );

      final stream = await mediaDevices.getUserMedia(constraints).toDart;
      _streams[viewId] = stream;
      video.srcObject = stream;
      widget.onStarted?.call();
    } catch (e) {
      widget.onError?.call('Akses kamera ditolak atau tidak tersedia: $e');
    }
  }

  void _stopCamera() {
    if (_currentViewId == null) return;
    final stream = _streams.remove(_currentViewId);
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (var i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        track.stop();
      }
    }
    final video = _videoElements.remove(_currentViewId);
    if (video != null) {
      video.srcObject = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: (int viewId) {
        _currentViewId = viewId;
        _startCamera(viewId);
      },
    );
  }
}
