import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class AppEnv {
  const AppEnv._();

  static const firebaseWebApiKey = 'AIzaSyCTcIqYgCdyc9pp-1V6TOnX8O1XNvK37cc';
  static const firebaseWebAppId = '1:756381611248:web:0cabf7509812600cd13e35';
  static const firebaseWebMessagingSenderId = '756381611248';
  static const firebaseWebProjectId = 'al-waqt-9cdb7';
  static const firebaseWebAuthDomain = 'al-waqt-9cdb7.firebaseapp.com';
  static const firebaseWebStorageBucket = 'al-waqt-9cdb7.firebasestorage.app';
  static const firebaseWebMeasurementId = 'G-NGP57MYQH5';
  static const firebaseWebVapidKey = 'BFdym5GFCnN7iJtECuYo-jOOOAehBCwkF8W8wei-qh7FSISLX0TmIy3kMBgcXw7fLrMpvN5RG-1XmnGvHWGkW2w';

  static const FirebaseOptions firebaseWebOptions = FirebaseOptions(
    apiKey: firebaseWebApiKey,
    appId: firebaseWebAppId,
    messagingSenderId: firebaseWebMessagingSenderId,
    projectId: firebaseWebProjectId,
    authDomain: firebaseWebAuthDomain,
    storageBucket: firebaseWebStorageBucket,
    measurementId: firebaseWebMeasurementId,
  );
}
