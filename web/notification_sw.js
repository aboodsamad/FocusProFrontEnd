// FocusPro push notification service worker.
// Registered at scope '/push-notifications/' so it coexists with Flutter's SW.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

// Receive push from backend (VAPID) and show browser notification
self.addEventListener('push', function (event) {
  if (!event.data) return;

  let data;
  try {
    data = event.data.json();
  } catch (_) {
    data = { title: 'FocusPro', body: event.data.text() };
  }

  const title = data.title || 'FocusPro';
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-96.png',
    requireInteraction: false,
    data: { url: '/' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Open the app when user taps notification
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      return clients.openWindow('/');
    })
  );
});
