// Appli Montoiz' Thaï Khmer Boxing : garde le site disponible sans réseau.
const V = "mtkb-v1";
const CORE = ["./", "index.html", "donnees.json", "manifest.json", "icon-192.png", "icon-512.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(V).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

// Réseau d'abord (toujours la dernière version), copie en cache si pas de réseau.
async function networkFirst(req, key) {
  const c = await caches.open(V);
  try {
    const res = await fetch(req, { cache: "no-store" });
    if (res.ok) c.put(key || req, res.clone());
    return res;
  } catch (_) {
    return (await c.match(key || req)) || (await c.match("index.html")) || Response.error();
  }
}
// Cache d'abord (photos, icônes, polices) : rapide et disponible hors ligne.
async function cacheFirst(req) {
  const c = await caches.open(V);
  const hit = await c.match(req);
  if (hit) return hit;
  try { const res = await fetch(req); if (res.ok || res.type === "opaque") c.put(req, res.clone()); return res; }
  catch (_) { return Response.error(); }
}

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname === "api.github.com" || url.hostname.endsWith("formsubmit.co")) return;
  if (url.origin === location.origin) {
    if (req.mode === "navigate" || url.pathname.endsWith("/index.html")) return e.respondWith(networkFirst(req, "index.html"));
    if (url.pathname.endsWith("/donnees.json")) return e.respondWith(networkFirst(req, "donnees.json"));
    return e.respondWith(cacheFirst(req));
  }
  if (url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com") return e.respondWith(cacheFirst(req));
});
