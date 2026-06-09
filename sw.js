// Service Worker — Logia Crisol del Elqui N°189
const CACHE = 'crisol-v8';   // ← cambiar versión invalida todo el caché anterior
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

// ── Badge counter (persiste en SW para cuando la app está cerrada) ──
let _swBadgeCount = 0;

function _swSetBadge(n) {
  _swBadgeCount = Math.max(0, n);
  if ('setAppBadge' in self.navigator) {
    if (_swBadgeCount > 0) self.navigator.setAppBadge(_swBadgeCount);
    else                   self.navigator.clearAppBadge();
  }
}

// ── PUSH NOTIFICATIONS ──
self.addEventListener('push', e => {
  let data = { title: 'Templo Crisol', body: 'Tienes un mensaje nuevo', url: '/intranet', badgeCount: null };
  try { if (e.data) data = { ...data, ...e.data.json() }; } catch {}

  // Actualizar badge del ícono: usar el contador enviado por el servidor o incrementar
  if (data.badgeCount != null) {
    _swSetBadge(data.badgeCount);
  } else {
    _swSetBadge(_swBadgeCount + 1);
  }

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

// ── Mensaje desde la app para sincronizar el badge real ──
self.addEventListener('message', e => {
  if (e.data?.type === 'SET_BADGE') {
    _swSetBadge(e.data.count ?? 0);
  }
});
