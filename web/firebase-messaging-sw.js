// Firebase Messaging Service Worker
// Rebuilt to be extremely robust for server-side push testing

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

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// Force immediate activation and take control of all clients
self.addEventListener('install', (event) => {
  console.log('[SW] Install event - forcing immediate activation');
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activate event - claiming all clients');
  event.waitUntil(
    self.clients.claim().then(() => {
      console.log('[SW] Successfully claimed clients');
    })
  );
});

// Recommended: Handle background messages via Firebase SDK
messaging.onBackgroundMessage((payload) => {
  console.log("[SW] Background message received via Firebase SDK:", payload);

  const title = payload.notification?.title || payload.data?.title || "Al-Waqt";
  const options = {
    body: payload.notification?.body || payload.data?.body || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    vibrate: [200, 100, 200],
    data: payload.data || {},
  };

  return self.registration.showNotification(title, options);
});

// Fallback: Listen to the raw 'push' event to guarantee delivery
// even if Firebase SDK onBackgroundMessage fails to trigger.
self.addEventListener('push', (event) => {
  console.log('[SW] Raw push event received:', event);
  
  if (!event.data) {
    console.warn('[SW] Push event has no data.');
    return;
  }

  // We let Firebase SDK process it if it can.
  // But if the push message contains a notification object that is not shown,
  // we show a fallback notification here.
  try {
    const data = event.data.json();
    console.log('[SW] Parsed push data:', data);

    // If the data is formatted as FCM notification, the SDK will handle it.
    // If it's a data payload or custom payload, we handle it explicitly.
    if (data.data || data.notification) {
      const title = data.notification?.title || data.data?.title || "Al-Waqt (Fallback)";
      const body = data.notification?.body || data.data?.body || "";
      
      event.waitUntil(
        self.registration.getNotifications().then((notifications) => {
          // Check if a notification with similar content is already showing to avoid duplicates
          const isDuplicate = notifications.some(n => n.title === title && n.body === body);
          if (isDuplicate) {
            console.log('[SW] Duplicate notification detected, skipping fallback show');
            return;
          }
          
          return self.registration.showNotification(title, {
            body: body,
            icon: "/icons/Icon-192.png",
            badge: "/icons/Icon-192.png",
            vibrate: [200, 100, 200],
            data: data.data || {},
          });
        })
      );
    }
  } catch (err) {
    console.error('[SW] Error parsing raw push data:', err);
    // If it's plain text:
    const text = event.data.text();
    console.log('[SW] Raw push text:', text);
    event.waitUntil(
      self.registration.showNotification("Al-Waqt Notification", {
        body: text,
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
      })
    );
  }
});

// Handle notification click event - open/focus app window
self.addEventListener("notificationclick", (event) => {
  console.log("[SW] Notification clicked:", event.notification);
  event.notification.close();

  const targetUrl = self.registration.scope || "/";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      // Prioritize focusing an existing window/tab
      for (const client of clients) {
        if (client.url.startsWith(targetUrl)) {
          return client.focus();
        }
      }
      // If no client open, open a new one
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});



