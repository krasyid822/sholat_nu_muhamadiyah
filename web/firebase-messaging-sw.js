// Firebase Messaging Service Worker
// Handles background push notifications for Al-Waqt PWA

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

// Do NOT use skipWaiting() here.
//
// skipWaiting() forces the new SW to take control immediately, even while
// the old SW is still handling push events. This can cause the browser to
// rotate push subscription encryption keys mid-session. If a cached FCM
// token still references the old keys, push messages encrypted with those
// old keys will fail to decrypt → "unrecognized Content-Encoding" error.
//
// Instead, let the browser naturally activate the new SW only when all
// clients (tabs/PWA windows) close and reopen. This ensures encryption
// keys stay synchronized.
self.addEventListener('install', (event) => {
  console.log('[SW] Install event — waiting for natural activation (no skipWaiting)');
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activate event — claiming clients');
  event.waitUntil(self.clients.claim());
});

// Handle push subscription changes.
//
// When the browser detects the push subscription's encryption keys have
// changed (e.g., after a SW update or browser key rotation), this event
// fires. We re-subscribe to keep push delivery working.
self.addEventListener('pushsubscriptionchange', (event) => {
  console.log('[SW] Push subscription changed — re-subscribing');
  event.waitUntil(
    self.registration.pushManager.subscribe(event.oldSubscription?.options ?? {
      userVisibleOnly: true,
    })
      .then((newSub) => {
        console.log('[SW] Re-subscribed successfully:', newSub.endpoint);
        // Notify all clients that the subscription changed so they can
        // refresh their FCM token.
        self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
          clients.forEach((client) => {
            client.postMessage({ type: 'PUSH_SUBSCRIPTION_CHANGED' });
          });
        });
      })
      .catch((err) => {
        console.error('[SW] Re-subscribe failed:', err);
      })
  );
});

// Handle background messages via Firebase SDK.
//
// This fires when a push arrives while the PWA is not in the foreground.
// Foreground messages are handled by messaging.onMessage() in index.html.
messaging.onBackgroundMessage((payload) => {
  console.log("[SW] Background message received:", payload);

  const title = payload.notification?.title || payload.data?.title || "Al-Waqt";
  const options = {
    body: payload.notification?.body || payload.data?.body || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    vibrate: [200, 100, 200],
    tag: 'fcm-bg-' + Date.now(),
    requireInteraction: true,
    data: payload.data || {},
  };

  return self.registration.showNotification(title, options);
});

// NOTE: We intentionally do NOT add a raw 'push' event listener here.
//
// The Firebase Messaging SDK (loaded via importScripts above) already
// registers its own internal 'push' event listener that:
//   1. Decrypts and parses the FCM payload
//   2. Routes foreground messages to onMessage() in the main page
//   3. Routes background messages to onBackgroundMessage() above
//
// Adding a second 'push' listener causes double-processing, race
// conditions, and can interfere with the SDK's decryption pipeline.

// Handle notification click — open/focus app window
self.addEventListener("notificationclick", (event) => {
  console.log("[SW] Notification clicked:", event.notification.tag);
  event.notification.close();

  const targetUrl = self.registration.scope || "/";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url.startsWith(targetUrl)) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
