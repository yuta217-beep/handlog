// HAND LOG service worker: 電波がなくてもアプリを開けるようにする
const CACHE = 'handlog-v1';
const SHELL = ['./', 'index.html', 'config.js', 'manifest.webmanifest', 'icons/icon-192.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.pathname.startsWith('/api/') || url.hostname.endsWith('supabase.co')) return; // データは常にネットから
  const isCdn = url.hostname === 'cdn.jsdelivr.net' || url.hostname.endsWith('googleapis.com') || url.hostname.endsWith('gstatic.com');
  if (url.origin !== location.origin && !isCdn) return;
  if (isCdn) { // 先にキャッシュ、裏で更新
    e.respondWith(caches.open(CACHE).then(async c => { const hit = await c.match(req); const net = fetch(req).then(r => { if (r.ok || r.type === 'opaque') c.put(req, r.clone()); return r; }).catch(() => hit); return hit || net; }));
    return;
  }
  // 自分のファイルはネット優先（更新をすぐ反映）、つながらなければキャッシュ
  e.respondWith(fetch(req).then(r => { if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return r; })
    .catch(() => caches.match(req).then(r => r || caches.match('index.html'))));
});
