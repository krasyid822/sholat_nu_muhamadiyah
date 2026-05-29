// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  print('🔄 Running Post-Build Service Worker Patch...');
  
  final file = File('build/web/flutter_service_worker.js');
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    
    // Check if the service worker already imports firebase-messaging-sw.js to prevent duplicate imports
    if (!content.contains('firebase-messaging-sw.js')) {
      // Append the importScripts call to the end of the file
      content += '\n// Firebase Cloud Messaging Web Push Integration\nimportScripts("firebase-messaging-sw.js");\n';
      file.writeAsStringSync(content);
      print('✅ Successfully patched build/web/flutter_service_worker.js with FCM integration!');
    } else {
      print('ℹ️ build/web/flutter_service_worker.js already patched.');
    }
  } else {
    print('⚠️ Warning: build/web/flutter_service_worker.js not found!');
  }
}
