export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/v1/delta") return new Response("not found", { status: 404 });

    const key = request.headers.get("x-api-key") || "";
    const allowed = (env.API_KEYS || "").split(",").map(s => s.trim()).filter(Boolean);
    if (!allowed.length || !allowed.includes(key)) return new Response("unauthorized", { status: 401 });

    const upstream = await fetch(env.DELTA_URL, { cf: { cacheTtl: 60, cacheEverything: true } });
    if (!upstream.ok) return new Response("upstream error", { status: 502 });

    return new Response(await upstream.text(), {
      status: 200,
      headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=60" },
    });
  },
};
