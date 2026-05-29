import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class WebARView extends StatefulWidget {
  const WebARView({super.key});

  @override
  State<WebARView> createState() => _WebARViewState();
}

class _WebARViewState extends State<WebARView> {
  static const String _viewType = 'ar-compass-view';
  static bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_isRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final element = web.document.getElementById('ar-compass-container');
        if (element == null) {
          final fallback = web.document.createElement('div') as web.HTMLDivElement;
          fallback.textContent = 'AR container tidak ditemukan';
          fallback.style.width = '100%';
          fallback.style.height = '100%';
          return fallback;
        }
        return element;
      });
      _isRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewType);
  }
}
