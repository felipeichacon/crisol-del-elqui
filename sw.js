// Service Worker — Logia Crisol del Elqui N°189
const CACHE = 'crisol-v3';   // ← cambiar versión invalida todo el caché anterior
const SHELL = ['/', '/logia-crisol-elqui.html', '/logo-crisol.png', '/manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  // Borrar cachés de versiones anteriores
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
