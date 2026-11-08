// Utilidades compartidas
(function () {
  const cfg = window.ALMUERZO_CONFIG || {};
  const listo = cfg.SUPABASE_URL && !cfg.SUPABASE_URL.startsWith("PEGUE");
  window.sb = listo ? supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY) : null;

  const MESES = ["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"];
  const DIAS = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"];

  window.AL = {
    fmt: n => new Intl.NumberFormat("es-CO", { style: "currency", currency: "COP", maximumFractionDigits: 0 }).format(Math.round(+n || 0)),
    toNum: s => { const d = String(s ?? "").replace(/[^\d]/g, ""); return d ? parseInt(d, 10) : 0; },
    // Fecha de hoy en Colombia, formato AAAA-MM-DD
    hoy: () => new Intl.DateTimeFormat("en-CA", { timeZone: "America/Bogota" }).format(new Date()),
    fechaTxt: iso => { const [y, m, d] = iso.split("-").map(Number); const dt = new Date(y, m - 1, d); return DIAS[dt.getDay()] + " " + d + " de " + MESES[m - 1]; },
    el: (tag, props = {}, kids = []) => {
      const e = document.createElement(tag);
      for (const [k, v] of Object.entries(props)) {
        if (k === "class") e.className = v;
        else if (k === "text") e.textContent = v;
        else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
        else if (v === true) e.setAttribute(k, "");
        else if (v !== false && v != null) e.setAttribute(k, v);
      }
      for (const c of [].concat(kids)) if (c != null) e.append(c);
      return e;
    },
    waNumber: raw => { let d = String(raw || "").replace(/\D/g, ""); if (d.length === 10 && d[0] === "3") d = "57" + d; return d; },
    slugify: s => String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40),
    sinConfig: () => !window.sb
  };
})();
