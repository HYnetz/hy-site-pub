export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    const okPath = (url.pathname === "/v1/delta" || url.pathname === "/v1/meta" || url.pathname === "/v1/status");
    if (!okPath) return new Response("not found", { status: 404 });

    const key = request.headers.get("x-api-key") || "";
    const allowed = (env.API_KEYS || "").split(",").map(s => s.trim()).filter(Boolean);
    if (!allowed.length || !allowed.includes(key)) return new Response("unauthorized", { status: 401 });

    async function fetchMeta() {
      const r = await fetch(env.META_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
      if (!r.ok) return null;
      try { return await r.json(); } catch { return null; }
    }

    if (url.pathname === "/v1/status") {
      const m = await fetchMeta() || {};
      return new Response(JSON.stringify({
        ok: true,
        updated_at: m.updated_at || m.updated || null,
        urls: m.urls || null,
        delta_new: m.delta_new || null
      }), { status: 200, headers: { "content-type": "application/json; charset=utf-8" }});
    }

    if (url.pathname === "/v1/meta") {
      const r = await fetch(env.META_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
      if (!r.ok) return new Response("upstream error", { status: 502 });
      return new Response(await r.text(), { status: 200, headers: { "content-type": "application/json; charset=utf-8" }});
    }

    const upstream = await fetch(env.DELTA_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
    if (!upstream.ok) return new Response("upstream error", { status: 502 });

    return new Response(await upstream.text(), {
      status: 200,
      headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=60" },
    });
  },
};
