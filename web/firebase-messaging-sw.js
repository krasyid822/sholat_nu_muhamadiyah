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

// Self-handling push event listener to ensure background notifications are displayed
// when the app is closed and the service worker is loaded via flutter_service_worker.js
self.addEventListener("push", (event) => {
  console.log("[firebase-messaging-sw.js] Push event intercepted:", event);

  if (!event.data) return;

  try {
    const payload = event.data.json();
    console.log("[firebase-messaging-sw.js] Intercepted payload:", payload);

    // Extract notification details from FCM payload structure
    const notification = payload.notification || payload.data;
    if (!notification) return;

    const title = notification.title || "Al-Waqt";
    const body = notification.body || "";

    // We check if the app is in the foreground (open).
    // If it is, the foreground listener in Dart handles showing the notification.
    event.waitUntil(
      self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
        const isAppFocused = clients.some(client => client.visibilityState === "visible");

        if (!isAppFocused) {
          const options = {
            body: body,
            icon: "icons/Icon-192.png",
            badge: "icons/Icon-192.png",
            vibrate: [200, 100, 200],
            data: payload.data || {},
          };

          return self.registration.showNotification(title, options);
        }
      })
    );
  } catch (e) {
    console.error("[firebase-messaging-sw.js] Error handling intercepted push event:", e);
  }
});

// Handle notification click event (open/focus app)
self.addEventListener("notificationclick", (event) => {
  console.log("[firebase-messaging-sw.js] Notification clicked:", event.notification);
  event.notification.close();

  // Define target URL (root of our app)
  const targetUrl = self.registration.scope || "/";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      // If a window is already open, focus it
      for (const client of clients) {
        if (client.url.startsWith(targetUrl) && "focus" in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});

