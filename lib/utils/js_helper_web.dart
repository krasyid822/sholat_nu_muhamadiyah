// ignore_for_file: avoid_web_libraries_in_flutter, undefined_function, deprecated_member_use
import 'dart:js' as js;

void fetchServiceWorkerStatus(void Function(String) callback) {
  try {
    js.context.callMethod('fetchServiceWorkerStatus', [
      js.allowInterop(callback)
    ]);
  } catch (e) {
    callback('Error: $e');
  }
}
