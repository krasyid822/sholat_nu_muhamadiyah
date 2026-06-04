import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class AdsenseTab extends StatefulWidget {
  const AdsenseTab({super.key});

  @override
  State<AdsenseTab> createState() => _AdsenseTabState();
}

class _AdsenseTabState extends State<AdsenseTab> {
  static const String _viewType = 'adsense-view';
  static bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_isRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
        iframe.src = 'adsense.html';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.border = 'none';
        return iframe;
      });
      _isRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewType);
  }
}
