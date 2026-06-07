// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  print('🔄 Running Post-Build Service Worker Patch...');
  
  final file = File('build/web/flutter_service_worker.js');
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    
    // Replace the deprecated Flutter self-destructing service worker completely
    // with a proxy to our custom Firebase service worker. This prevents the infinite reload loop.
    content = '// Proxy to Firebase FCM Service Worker\nimportScripts("firebase-messaging-sw.js");\n';
    file.writeAsStringSync(content);
    print('✅ Successfully replaced build/web/flutter_service_worker.js with FCM integration!');
  } else {
    print('⚠️ Warning: build/web/flutter_service_worker.js not found!');
  }
}
