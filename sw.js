// Service Worker — Logia Crisol del Elqui N°189
const CACHE = 'crisol-v6';   // ← cambiar versión invalida todo el caché anterior
const SHELL = ['/', '/logia-crisol-elqui.html', '/logo-crisol.png', '/manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = e.request.url;

  // Pasar sin interceptar: Supabase, fuentes, CDN externos
  if (url.includes('supabase.co') || url.includes('googleapis') ||
      url.includes('gstatic.com') || url.includes('jsdelivr.net')) {
    return;
  }

  // ── HTML: network-first (siempre recibe la versión más reciente) ──
  const isHTML = url.endsWith('.html') || url.endsWith('/') ||
                 e.request.headers.get('accept')?.includes('text/html');

  if (isHTML) {
    e.respondWith(
      fetch(e.request)
        .then(res => {
          if (res && res.status === 200) {
            caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          }
          return res;
        })
        .catch(() => caches.match(e.request)) // offline: usar caché
    );
    return;
  }

  // ── Otros assets (imágenes, JS, etc.): cache-first ──
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(res => {
        if (res && res.status === 200 && e.request.method === 'GET') {
          caches.open(CACHE).then(c => c.put(e.request, res.clone()));
        }
        return res;
      });
    })
  );
});

// ── PUSH NOTIFICATIONS ──
self.addEventListener('push', e => {
  let data = { title: 'Templo Crisol', body: 'Tienes un mensaje nuevo', url: '/intranet' };
  try { if (e.data) data = { ...data, ...e.data.json() }; } catch {}

  e.waitUntil(
    self.registration.showNotification(data.title, {
      body:    data.body,
      icon:    '/logo-crisol.png',
      badge:   '/logo-crisol.png',
      vibrate: [200, 100, 200],
      tag:     'crisol-msg',           // agrupa notificaciones del mismo tipo
      renotify: true,
      data:    { url: data.url }
    })
  );
});

// ── CLICK EN NOTIFICACIÓN ──
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const target = e.notification.data?.url || '/intranet';
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      // Si la app ya está abierta, enfocarla
      for (const client of list) {
        if (client.url.includes('crisoldelelqui.cl') && 'focus' in client) {
          return client.focus();
        }
      }
      // Si no, abrirla
      return clients.openWindow('https://crisoldelelqui.cl' + target);
    })
  );
});
