// Firebase Messaging Service Worker
// Required for receiving push notifications in the background on web

importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");
const firebaseConfig = {
  apiKey: "AIzaSyCTcIqYgCdyc9pp-1V6TOnX8O1XNvK37cc",
  authDomain: "al-waqt-9cdb7.firebaseapp.com",
  projectId: "al-waqt-9cdb7",
  storageBucket: "al-waqt-9cdb7.firebasestorage.app",
  messagingSenderId: "756381611248",
  appId: "1:756381611248:web:0cabf7509812600cd13e35",
  measurementId: "G-NGP57MYQH5"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((message) => {
  console.log("[firebase-messaging-sw.js] Background message received:", message);

  const notificationTitle = message.notification?.title || "Al-Waqt";
  const notificationOptions = {
    body: message.notification?.body || "",
    icon: "icons/Icon-192.png",
    badge: "icons/Icon-192.png",
    vibrate: [200, 100, 200],
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
