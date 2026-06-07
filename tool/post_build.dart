// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  print('🔄 Running Post-Build Service Worker Patch...');
  
  // Step 1: Replace flutter_service_worker.js with a proxy to firebase-messaging-sw.js
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

  // Step 2: Strip serviceWorkerSettings from flutter_bootstrap.js
  //
  // Flutter's bootstrap registers flutter_service_worker.js?v=<hash> where <hash>
  // changes every build. Even though the SW content is identical (our 2-line proxy),
  // the changing URL triggers the browser's SW update check. Combined with
  // skipWaiting() + clients.claim(), this can rotate push subscription encryption
  // keys mid-session, causing FCM push decryption failures.
  //
  // By removing serviceWorkerSettings entirely, we prevent Flutter from touching
  // the SW lifecycle. Our registerFirebaseMessagingSW() in index.html is the sole
  // owner of SW registration.
  final bootstrapFile = File('build/web/flutter_bootstrap.js');
  if (bootstrapFile.existsSync()) {
    var bootstrapContent = bootstrapFile.readAsStringSync();
    final original = bootstrapContent;

    // Remove the serviceWorkerSettings key-value pair from the _flutter.loader.load() call.
    // The generated code looks like:
    //   _flutter.loader.load({ serviceWorkerSettings: { serviceWorkerVersion: "..." } });
    // We want:
    //   _flutter.loader.load({});
    bootstrapContent = bootstrapContent.replaceAll(
      RegExp(r'serviceWorkerSettings:\s*\{[^}]*\},?\s*'),
      '',
    );

    if (bootstrapContent != original) {
      bootstrapFile.writeAsStringSync(bootstrapContent);
      print('✅ Stripped serviceWorkerSettings from flutter_bootstrap.js');
    } else {
      print('ℹ️ No serviceWorkerSettings found in flutter_bootstrap.js (already clean)');
    }
  } else {
    print('⚠️ Warning: build/web/flutter_bootstrap.js not found!');
  }
}
