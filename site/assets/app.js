// Theme switch, mobile menu, copy buttons, "On this page" highlighting and ⌘K search. No dependencies.
(() => {
  const root = document.documentElement;

  // Theme: follows the system until the visitor picks one, then remembers it.
  document.querySelectorAll("[data-theme-toggle]").forEach((button) =>
    button.addEventListener("click", () => {
      const dark = root.dataset.theme
        ? root.dataset.theme === "dark"
        : matchMedia("(prefers-color-scheme: dark)").matches;
      root.dataset.theme = dark ? "light" : "dark";
      try { localStorage.setItem("theme", root.dataset.theme); } catch (e) {}
    })
  );

  // Mobile menu: the docs sidebar slides in.
  const menuButton = document.querySelector("[data-menu-toggle]");
  const menu = document.querySelector("[data-menu]");
  const setMenu = (open) => {
    document.body.classList.toggle("menu-open", open);
    menuButton?.setAttribute("aria-expanded", String(open));
  };
  menuButton?.addEventListener("click", () => {
    if (!menu) { location.href = "guide.html"; return; }
    setMenu(!document.body.classList.contains("menu-open"));
  });
  document.addEventListener("click", (event) => {
    if (document.body.classList.contains("menu-open") && !menu.contains(event.target) && !menuButton.contains(event.target)) setMenu(false);
  });

  // Code blocks get a copy button.
  document.querySelectorAll(".prose pre").forEach((pre) => {
    const wrap = document.createElement("div");
    wrap.className = "code";
    pre.replaceWith(wrap);
    wrap.append(pre);
    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy";
    button.textContent = "Copy";
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(pre.innerText.trim());
        button.textContent = "Copied";
        button.classList.add("done");
        setTimeout(() => { button.textContent = "Copy"; button.classList.remove("done"); }, 1600);
      } catch (e) {}
    });
    wrap.append(button);
  });

  // "On this page": highlight the section being read.
  const tocLinks = [...document.querySelectorAll(".doc-toc a")];
  if (tocLinks.length && "IntersectionObserver" in window) {
    const byId = new Map(tocLinks.map((a) => [decodeURIComponent(a.hash.slice(1)), a]));
    const visible = new Set();
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((e) => (e.isIntersecting ? visible.add(e.target.id) : visible.delete(e.target.id)));
      const headings = [...byId.keys()].map((id) => document.getElementById(id)).filter(Boolean);
      const current = headings.find((h) => visible.has(h.id)) ||
        headings.filter((h) => h.getBoundingClientRect().top < 120).pop();
      tocLinks.forEach((a) => a.classList.toggle("active", current && byId.get(current.id) === a));
    }, { rootMargin: "-64px 0px -60% 0px" });
    byId.forEach((_, id) => { const h = document.getElementById(id); if (h) observer.observe(h); });
  }

  // Search: loads the index on first use; every word must match.
  const dialog = document.querySelector("[data-search]");
  const input = document.querySelector("[data-search-input]");
  const list = document.querySelector("[data-search-results]");
  let index = null;
  let selected = 0;
  let lastFocus = null;

  const escapeHTML = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const highlight = (text, words) => {
    let out = escapeHTML(text);
    words.forEach((w) => { out = out.replace(new RegExp(`(${w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "ig"), "<mark>$1</mark>"); });
    return out;
  };
  const snippet = (text, word) => {
    const at = text.toLowerCase().indexOf(word);
    if (at < 60) return text.slice(0, 160);
    return "…" + text.slice(at - 50, at + 110);
  };

  const render = () => {
    const words = input.value.toLowerCase().split(/\s+/).filter(Boolean);
    if (!index) return;
    const results = words.length === 0 ? [] : index
      .map((entry) => {
        const title = entry.title.toLowerCase(), text = entry.text.toLowerCase();
        if (!words.every((w) => title.includes(w) || text.includes(w))) return null;
        const score = words.reduce((s, w) => s + (title.includes(w) ? 10 : 0) + (title.startsWith(w) ? 5 : 0), 0);
        return { entry, score };
      })
      .filter(Boolean)
      .sort((a, b) => b.score - a.score)
      .slice(0, 12);
    selected = 0;
    if (!words.length) { list.innerHTML = '<li class="search-empty">Type to search the docs.</li>'; return; }
    if (!results.length) { list.innerHTML = `<li class="search-empty">No results for “${escapeHTML(input.value)}”.</li>`; return; }
    list.innerHTML = results.map(({ entry }, i) =>
      `<li><a href="${entry.url}" role="option" aria-selected="${i === 0}"><small>${escapeHTML(entry.page)}</small>` +
      `<strong>${highlight(entry.title, words)}</strong><p>${highlight(snippet(entry.text, words[0]), words)}</p></a></li>`).join("");
  };

  const open = async () => {
    lastFocus = document.activeElement;
    dialog.hidden = false;
    input.value = "";
    input.focus();
    if (!index) {
      try { index = await (await fetch("search-index.json")).json(); } catch (e) { index = []; }
    }
    render();
  };
  const close = () => { dialog.hidden = true; lastFocus?.focus(); };

  document.querySelectorAll("[data-search-open]").forEach((b) => b.addEventListener("click", open));
  document.querySelectorAll("[data-search-close]").forEach((b) => b.addEventListener("click", close));
  input?.addEventListener("input", render);
  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { event.preventDefault(); dialog.hidden ? open() : close(); return; }
    if (event.key === "/" && dialog.hidden && !/input|textarea/i.test(document.activeElement.tagName)) { event.preventDefault(); open(); return; }
    if (dialog.hidden) return;
    const links = [...list.querySelectorAll("a")];
    if (event.key === "Escape") close();
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      if (!links.length) return;
      selected = (selected + (event.key === "ArrowDown" ? 1 : -1) + links.length) % links.length;
      links.forEach((a, i) => a.setAttribute("aria-selected", String(i === selected)));
      links[selected].scrollIntoView({ block: "nearest" });
    }
    if (event.key === "Enter" && links[selected]) { event.preventDefault(); location.href = links[selected].href; }
  });
})();
