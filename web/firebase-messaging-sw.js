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

// Register standard push event listener (PWABuilder / W3C Push API specification)
self.addEventListener('push', (event) => {
  console.log('[SW] Push event received:', event);

  let data = {};
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data = { body: event.data.text() };
    }
  }

  // If the push is a proprietary FCM message, let the Firebase Messaging SDK's
  // internal push handler process it to avoid duplicate notifications.
  if (data.from || data.gcm || data.google || (data.data && (data.data.from || data.data.gcm))) {
    console.log('[SW] FCM-specific push payload detected. Delegating to Firebase SDK.');
    return;
  }

  // Otherwise, handle it as a standard Web Push / PWABuilder native notification
  const title = data.title || data.notification?.title || "Al-Waqt";
  const options = {
    body: data.body || data.notification?.body || "",
    icon: data.icon || data.notification?.icon || "/icons/Icon-192.png",
    badge: data.badge || data.notification?.badge || "/icons/Icon-192.png",
    vibrate: data.vibrate || [200, 100, 200],
    tag: data.tag || 'pwa-push-notification',
    requireInteraction: true,
    data: data.data || data
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

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

// --- Offline Support Integration (MDN js13kGames PWA Tutorial Pattern) ---
const cacheName = "al-waqt-v1";
const appShellFiles = [
  "./",
  "./index.html",
  "./flutter_bootstrap.js",
  "./flutter.js",
  "./main.dart.js",
  "./manifest.json",
  "./favicon.png",
  "./icons/Icon-192.png",
  "./icons/Icon-512.png",
  "./icons/Icon-maskable-192.png",
  "./icons/Icon-maskable-512.png",
  "./azan.mp3"
];

// Pre-cache App Shell during installation
self.addEventListener("install", (event) => {
  console.log("[SW] Install event — caching App Shell");
  event.waitUntil(
    (async () => {
      const cache = await caches.open(cacheName);
      try {
        await cache.addAll(appShellFiles);
        console.log("[SW] App Shell pre-cached successfully");
      } catch (err) {
        console.error("[SW] Pre-caching App Shell failed:", err);
      }
    })()
  );
});

// Clear outdated caches during activation
self.addEventListener("activate", (event) => {
  console.log("[SW] Activate event — clearing old caches");
  event.waitUntil(
    (async () => {
      const keyList = await caches.keys();
      await Promise.all(
        keyList.map((key) => {
          if (key !== cacheName) {
            console.log("[SW] Deleting old cache:", key);
            return caches.delete(key);
          }
        })
      );
    })()
  );
});

// Intercept fetch requests (Cache-first with Network Fallback & Dynamic Caching)
self.addEventListener("fetch", (event) => {
  // Only handle GET requests and avoid non-http/https schemes
  if (event.request.method !== "GET") return;
  
  const url = new URL(event.request.url);
  if (!url.protocol.startsWith("http")) return;

  // Avoid caching browser extensions, Firebase API requests, or FCM messaging endpoints
  if (
    url.hostname.includes("googleapis.com") || 
    url.hostname.includes("firebase.com") || 
    url.hostname.includes("firebaseinstallations.googleapis.com") ||
    url.pathname.includes("/__/")
  ) {
    return;
  }

  event.respondWith(
    (async () => {
      const cachedResponse = await caches.match(event.request);
      if (cachedResponse) {
        return cachedResponse;
      }

      try {
        const networkResponse = await fetch(event.request);
        if (networkResponse && networkResponse.status === 200) {
          const cache = await caches.open(cacheName);
          cache.put(event.request, networkResponse.clone());
        }
        return networkResponse;
      } catch (error) {
        console.warn("[SW] Fetch failed, resource not in cache and network offline:", event.request.url);
        // If index.html fails, return the cached root/index.html
        if (event.request.mode === "navigate") {
          const rootCache = await caches.match("./index.html") || await caches.match("./");
          if (rootCache) return rootCache;
        }
        throw error;
      }
    })()
  );
});

// --- Background Sync Integration ---
self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync event fired:', event.tag);
  if (event.tag === 'sync-app-data') {
    event.waitUntil(
      (async () => {
        console.log('[SW] Syncing app data in background...');
        try {
          const response = await fetch('./version.json');
          if (response && response.status === 200) {
            console.log('[SW] Background sync successfully reached server.');
          }
        } catch (err) {
          console.warn('[SW] Background sync failed to connect to server:', err);
        }
      })()
    );
  }
});

// --- Periodic Background Sync Integration ---
self.addEventListener('periodicsync', (event) => {
  console.log('[SW] Periodic background sync event fired:', event.tag);
  if (event.tag === 'update-app-cache') {
    event.waitUntil(
      (async () => {
        console.log('[SW] Running periodic background sync...');
        try {
          const cache = await caches.open(cacheName);
          const urlsToUpdate = ['./version.json', './index.html', './manifest.json'];
          await Promise.all(
            urlsToUpdate.map(async (url) => {
              try {
                const response = await fetch(url, { cache: 'reload' });
                if (response.status === 200) {
                  await cache.put(url, response);
                  console.log(`[SW] Periodic sync updated cache for: ${url}`);
                }
              } catch (e) {
                console.warn(`[SW] Periodic sync failed to update cache for ${url}:`, e);
              }
            })
          );
        } catch (err) {
          console.error('[SW] Periodic background sync failed:', err);
        }
      })()
    );
  }
});
