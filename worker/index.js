export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/v1/delta") return new Response("not found", { status: 404 });

    const key = request.headers.get("x-api-key") || "";
    const allowed = (env.API_KEYS || "").split(",").map(s => s.trim()).filter(Boolean);
    if (!allowed.length || !allowed.includes(key)) return new Response("unauthorized", { status: 401 });

    // status/meta do not require full delta fetch
    if (url.pathname === "/v1/status") {
      const meta = await fetch(env.META_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
      const mj = meta.ok ? await meta.json() : {};
      return new Response(JSON.stringify({
        ok: true,
        updated_at: mj.updated_at || mj.updated || null,
        urls: mj.urls || null,
        delta_new: mj.delta_new || null
      }), { status: 200, headers: { "content-type": "application/json; charset=utf-8" }});
    }

    if (url.pathname === "/v1/meta") {
      const meta = await fetch(env.META_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
      if (!meta.ok) return new Response("upstream error", { status: 502 });
      return new Response(await meta.text(), { status: 200, headers: { "content-type": "application/json; charset=utf-8" }});
    }


    const upstream = await fetch(env.DELTA_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
    if (!upstream.ok) return new Response("upstream error", { status: 502 });

    return new Response(await upstream.text(), {
      status: 200,
      headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=60" },
    });
  },
};
