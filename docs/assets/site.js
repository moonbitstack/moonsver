/* moonsver site — shared behaviour: theme, navigation, code tools, alignment. */
(function () {
  "use strict";

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  /* ---------------- theme ---------------- */
  (function theme() {
    const root = document.documentElement;
    const btn = $(".theme-btn");
    if (!btn) return;
    const current = () => {
      const t = root.getAttribute("data-theme");
      if (t === "dark" || t === "light") return t;
      return "light";
    };
    const label = (mode) =>
      mode === "dark" ? "Switch to light theme" : "Switch to dark theme";
    btn.setAttribute("aria-label", label(current()));
    btn.addEventListener("click", () => {
      const next = current() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("theme", next); } catch (e) {}
      btn.setAttribute("aria-label", label(next));
    });
  })();

  /* ---------------- mobile navigation ---------------- */
  (function nav() {
    const btn = $(".menu-btn");
    if (!btn) return;
    btn.addEventListener("click", () => {
      const open = btn.getAttribute("aria-expanded") === "true";
      btn.setAttribute("aria-expanded", String(!open));
    });
    $$(".topnav a").forEach((a) =>
      a.addEventListener("click", () => btn.setAttribute("aria-expanded", "false"))
    );
  })();

  /* ---------------- code: copy + width-aware alignment ---------------- */
  (function codeTools() {
    const hasSegmenter = typeof Intl !== "undefined" && Intl.Segmenter;
    const segmenter = hasSegmenter ? new Intl.Segmenter(undefined, { granularity: "grapheme" }) : null;

    const graphemes = (text) => {
      if (segmenter) return Array.from(segmenter.segment(text), (s) => s.segment);
      return Array.from(text);
    };

    // East Asian wide / emoji take two cells; everything else one.
    const isWide = (cp) => {
      return (
        (cp >= 0x1100 && cp <= 0x115f) ||
        (cp >= 0x2e80 && cp <= 0x303e) ||
        (cp >= 0x3041 && cp <= 0x33ff) ||
        (cp >= 0x3400 && cp <= 0x4dbf) ||
        (cp >= 0x4e00 && cp <= 0x9fff) ||
        (cp >= 0xa000 && cp <= 0xa4cf) ||
        (cp >= 0xac00 && cp <= 0xd7a3) ||
        (cp >= 0xf900 && cp <= 0xfaff) ||
        (cp >= 0xfe30 && cp <= 0xfe4f) ||
        (cp >= 0xff00 && cp <= 0xff60) ||
        (cp >= 0xffe0 && cp <= 0xffe6) ||
        (cp >= 0x1f300 && cp <= 0x1faff) ||
        (cp >= 0x20000 && cp <= 0x3fffd)
      );
    };

    const escapeHtml = (s) =>
      s.replace(/[&<>]/g, (c) => (c === "&" ? "&amp;" : c === "<" ? "&lt;" : "&gt;"));

    const widthOf = (text) =>
      graphemes(text).reduce((w, g) => {
        const cp = g.codePointAt(0) || 0;
        return w + (isWide(cp) ? 2 : 1);
      }, 0);

    // Wrap non-ASCII grapheme clusters in fixed-width spans so the box width is
    // exact no matter which fallback font draws the glyph.
    const spanify = (text) => {
      let out = "";
      let ascii = "";
      const flush = () => {
        if (ascii) { out += escapeHtml(ascii); ascii = ""; }
      };
      for (const g of graphemes(text)) {
        const cp = g.codePointAt(0) || 0;
        if (cp < 128) {
          ascii += g;
        } else {
          flush();
          const cls = isWide(cp) ? "w2" : "w1";
          out += `<span class="${cls}">${escapeHtml(g)}</span>`;
        }
      }
      flush();
      return out;
    };

    // Find a trailing line comment outside of string literals.
    const commentIndex = (line) => {
      let quote = null;
      for (let i = 0; i < line.length - 1; i++) {
        const ch = line[i];
        if (quote) {
          if (ch === "\\") { i++; continue; }
          if (ch === quote) quote = null;
          continue;
        }
        if (ch === '"' || ch === "'" || ch === "`") { quote = ch; continue; }
        if (ch === "/" && line[i + 1] === "/" && i > 0 && /\s/.test(line[i - 1])) {
          return i;
        }
      }
      return -1;
    };

    const align = (pre) => {
      const raw = pre.textContent.replace(/\s+$/, "");
      pre.dataset.raw = raw;
      const lines = raw.split("\n");
      const parts = lines.map((line) => {
        const idx = commentIndex(line);
        if (idx < 0) return { code: line, comment: null };
        return { code: line.slice(0, idx).replace(/\s+$/, ""), comment: line.slice(idx) };
      });
      let target = 0;
      for (const p of parts) {
        if (p.comment) target = Math.max(target, widthOf(p.code) + 2);
      }
      if (!target) return;
      const html = parts
        .map((p) => {
          if (!p.comment) return spanify(p.code);
          const pad = Math.max(2, target - widthOf(p.code));
          return spanify(p.code) + " ".repeat(pad) + spanify(p.comment);
        })
        .join("\n");
      pre.innerHTML = html;
    };

    $$("pre").forEach((pre) => {
      if (pre.closest(".code-block")) return;
      if (pre.classList.contains("no-copy")) return;
      const isSig = pre.classList.contains("sig");
      const wrap = document.createElement("div");
      wrap.className = "code-block" + (isSig ? " is-sig" : "");
      pre.parentNode.insertBefore(wrap, pre);
      wrap.appendChild(pre);
      if (pre.hasAttribute("data-align")) {
        const raw = pre.textContent;
        align(pre);
        pre.dataset.raw = raw;
      }
      if (isSig) return;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "copy";
      btn.textContent = "copy";
      btn.addEventListener("click", async () => {
        const text = pre.dataset.raw || pre.textContent;
        try {
          await navigator.clipboard.writeText(text);
          btn.textContent = "copied";
          btn.classList.add("done");
          setTimeout(() => { btn.textContent = "copy"; btn.classList.remove("done"); }, 1400);
        } catch (e) {
          btn.textContent = "copy failed";
          setTimeout(() => { btn.textContent = "copy"; }, 1400);
        }
      });
      wrap.appendChild(btn);
    });
  })();

  /* ---------------- scroll-spy for the table of contents ---------------- */
  (function spy() {
    const links = $$(".toc a[href^='#']");
    if (!links.length) return;
    const map = new Map();
    links.forEach((a) => {
      const id = a.getAttribute("href").slice(1);
      const el = document.getElementById(id);
      if (el) map.set(el, a);
    });
    if (!map.size) return;
    const setActive = (a) => {
      links.forEach((l) => l.classList.remove("active"));
      if (a) a.classList.add("active");
    };
    const obs = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (visible.length) setActive(map.get(visible[0].target));
      },
      { rootMargin: "-84px 0px -62% 0px", threshold: 0 }
    );
    map.forEach((_, el) => obs.observe(el));
  })();
})();
