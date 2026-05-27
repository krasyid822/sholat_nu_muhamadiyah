// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  print('🔄 Running Dart PWA Version Bumper...');
  
  // 1. Update pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    var content = pubspecFile.readAsStringSync();
    final regExp = RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)');
    final match = regExp.firstMatch(content);
    if (match != null) {
      final ver = match.group(1);
      final build = int.parse(match.group(2)!);
      final nextBuild = build + 1;
      final newVerLine = 'version: $ver+$nextBuild';
      content = content.replaceFirst(regExp, newVerLine);
      pubspecFile.writeAsStringSync(content);
      print('✅ pubspec.yaml bumped to: $ver+$nextBuild');
    }
  }

  // 2. Update index.html service worker version cache-buster
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    var content = indexFile.readAsStringSync();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    
    // We update the flutter_bootstrap.js import to include a cache-buster query parameter
    final regExp = RegExp(r'flutter_bootstrap\.js(\?v=[a-zA-Z0-9_\-]+)?');
    if (content.contains(regExp)) {
      content = content.replaceAll(regExp, 'flutter_bootstrap.js?v=$timestamp');
      indexFile.writeAsStringSync(content);
      print('✅ web/index.html cache buster updated: ?v=$timestamp');
    }
  }
}
