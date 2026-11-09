// Mus'haf reader service worker — offline support.
// Page scans (/pages/*.png) are cached forever on first view (they never change);
// the reader shell uses network-first so updates arrive, with cache fallback.
const SHELL = 'mushaf-shell-v3';
const PAGES = 'mushaf-pages-v3';
const SHELL_URLS = ['reader.html', 'manifest.webmanifest', 'assets/icon.png',
                    'data/ayah_boxes.json', 'data/ayah_text.json'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(SHELL).then((c) => c.addAll(SHELL_URLS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== SHELL && k !== PAGES).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (url.origin !== location.origin) return; // fonts etc. — leave to the browser

  // Page scans + ayah data: cache-first (immutable content).
  if (url.pathname.includes('/pages/') || url.pathname.includes('/data/')) {
    e.respondWith(
      caches.open(PAGES).then((c) =>
        c.match(e.request).then((hit) =>
          hit || fetch(e.request).then((res) => {
            if (res.ok) c.put(e.request, res.clone());
            return res;
          })
        )
      )
    );
    return;
  }

  // Shell: network-first with cache fallback (so the reader works offline).
  e.respondWith(
    fetch(e.request).then((res) => {
      if (res.ok && e.request.method === 'GET') {
        const copy = res.clone();
        caches.open(SHELL).then((c) => c.put(e.request, copy));
      }
      return res;
    }).catch(() => caches.match(e.request))
  );
});
