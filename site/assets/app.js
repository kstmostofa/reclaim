// Theme, menu, scroll effects, the live scan demo, the screenshot tour, copy buttons, the outline and ⌘K search.
(() => {
  const root = document.documentElement;
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ------------------------------------------------------------------ Theme
  document.querySelectorAll("[data-theme-toggle]").forEach((button) =>
    button.addEventListener("click", () => {
      const dark = root.dataset.theme ? root.dataset.theme === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
      root.dataset.theme = dark ? "light" : "dark";
      try { localStorage.setItem("theme", root.dataset.theme); } catch (e) {}
    })
  );

  // ------------------------------------------------------------------ Mobile menu
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
    if (menu && document.body.classList.contains("menu-open") && !menu.contains(event.target) && !menuButton.contains(event.target)) setMenu(false);
  });

  // ------------------------------------------------------------------ Scroll: header border and reading progress
  const progress = document.querySelector(".progress");
  const onScroll = () => {
    document.body.classList.toggle("scrolled", scrollY > 8);
    if (progress) {
      const max = document.documentElement.scrollHeight - innerHeight;
      progress.style.setProperty("--p", max > 0 ? Math.min(1, scrollY / max) : 0);
    }
  };
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // ------------------------------------------------------------------ Reveal on scroll, with count-ups
  const countUp = (el) => {
    const target = parseFloat(el.dataset.count);
    const decimals = (el.dataset.count.split(".")[1] || "").length;
    const suffix = el.dataset.suffix || "";
    if (reduced) { el.textContent = target.toFixed(decimals) + suffix; return; }
    const start = performance.now();
    const step = (now) => {
      const t = Math.min(1, (now - start) / 1400);
      const eased = 1 - Math.pow(1 - t, 3);
      el.textContent = (target * eased).toFixed(decimals) + suffix;
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };
  const revealables = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reduced) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("in");
        entry.target.querySelectorAll("[data-count]").forEach(countUp);
        io.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
    revealables.forEach((el) => io.observe(el));
  } else {
    revealables.forEach((el) => { el.classList.add("in"); el.querySelectorAll("[data-count]").forEach(countUp); });
  }

  // ------------------------------------------------------------------ Spotlight that follows the pointer on cards
  document.querySelectorAll(".tile, .card-link").forEach((card) =>
    card.addEventListener("pointermove", (event) => {
      const box = card.getBoundingClientRect();
      card.style.setProperty("--mx", `${event.clientX - box.left}px`);
      card.style.setProperty("--my", `${event.clientY - box.top}px`);
    })
  );

  // ------------------------------------------------------------------ Screenshot tour
  document.querySelectorAll("[data-tour]").forEach((tour) => {
    const tabs = [...tour.querySelectorAll("[role=tab]")];
    const panels = [...tour.querySelectorAll("[role=tabpanel]")];
    let timer = null;
    const show = (i) => {
      tabs.forEach((t, j) => { t.setAttribute("aria-selected", String(i === j)); t.tabIndex = i === j ? 0 : -1; });
      panels.forEach((p, j) => p.classList.toggle("active", i === j));
    };
    const auto = () => {
      if (reduced) return;
      clearInterval(timer);
      timer = setInterval(() => show((tabs.findIndex((t) => t.getAttribute("aria-selected") === "true") + 1) % tabs.length), 6000);
    };
    tabs.forEach((tab, i) => {
      tab.addEventListener("click", () => { show(i); clearInterval(timer); });
      tab.addEventListener("keydown", (e) => {
        if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
        const next = (i + (e.key === "ArrowRight" ? 1 : -1) + tabs.length) % tabs.length;
        show(next); tabs[next].focus(); clearInterval(timer);
      });
    });
    show(0);
    auto();
  });

  // ------------------------------------------------------------------ The live scan demo in the hero
  const scan = document.querySelector("[data-scan]");
  if (scan) {
    const items = [
      { name: "node_modules", where: "~/Projects/shop", size: 1.42, level: "rebuild" },
      { name: ".next", where: "~/Projects/shop", size: 0.86, level: "safe" },
      { name: "DerivedData", where: "~/Library/Developer/Xcode", size: 6.8, level: "safe" },
      { name: "Build cache", where: "Docker · OrbStack", size: 0.89, level: "safe" },
      { name: "caches", where: "~/.gradle", size: 1.16, level: "safe" },
      { name: "vendor", where: "~/Projects/api", size: 0.31, level: "rebuild" },
      { name: "Installer.dmg", where: "~/Downloads · 7 months old", size: 2.3, level: "personal" },
    ];
    const list = scan.querySelector("[data-list]");
    const total = scan.querySelector("[data-total]");
    const label = scan.querySelector("[data-total-label]");
    const status = scan.querySelector("[data-status]");
    const del = scan.querySelector("[data-delete]");
    const bar = scan.querySelector(".scan-progress");
    const check = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
    const levels = { safe: "Safe", rebuild: "Rebuild", personal: "Personal" };
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    const fmt = (gb) => gb.toFixed(1) + " GB";

    const tween = (from, to, ms, fn) => new Promise((resolve) => {
      const start = performance.now();
      const step = (now) => {
        const t = Math.min(1, (now - start) / ms);
        fn(from + (to - from) * (1 - Math.pow(1 - t, 3)));
        t < 1 ? requestAnimationFrame(step) : resolve();
      };
      requestAnimationFrame(step);
    });

    const render = () => {
      list.innerHTML = items.map((it) =>
        `<li data-level="${it.level}" title="${it.where}"><span class="chk">${check}</span><span><code>${it.name}</code></span>` +
        `<span class="badge ${it.level}">${levels[it.level]}</span><span class="size">${fmt(it.size)}</span></li>`).join("");
    };

    const finalState = () => {
      render();
      const rows = [...list.children];
      rows.forEach((li) => li.classList.add("on"));
      rows.filter((li) => li.dataset.level === "safe").forEach((li) => li.classList.add("ticked"));
      scan.classList.add("found");
      const sum = items.reduce((s, it) => s + it.size, 0);
      total.textContent = fmt(sum);
      status.textContent = `Found ${items.length} items`;
      const safe = items.filter((it) => it.level === "safe");
      del.textContent = `Delete ${safe.length} items · ${fmt(safe.reduce((s, it) => s + it.size, 0))}`;
    };

    const run = async () => {
      while (true) {
        render();
        scan.classList.remove("found");
        total.textContent = "0.0 GB";
        label.textContent = "reclaimable";
        status.textContent = "Scanning Macintosh HD…";
        del.textContent = "Delete 0 items";
        bar.style.transition = "none"; bar.style.width = "0";
        await sleep(400);
        bar.style.transition = `width ${items.length * 0.55 + 0.4}s linear`; bar.style.width = "100%";
        let sum = 0;
        for (const [i, li] of [...list.children].entries()) {
          await sleep(550);
          li.classList.add("on");
          const before = sum; sum += items[i].size;
          tween(before, sum, 450, (v) => (total.textContent = fmt(v)));
        }
        await sleep(500);
        scan.classList.add("found");
        status.textContent = `Found ${items.length} items`;
        const safeRows = [...list.children].filter((li) => li.dataset.level === "safe");
        const safeSum = items.filter((it) => it.level === "safe").reduce((s, it) => s + it.size, 0);
        for (const [i, li] of safeRows.entries()) {
          await sleep(260);
          li.classList.add("ticked");
          del.textContent = `Delete ${i + 1} items · ${fmt(items.filter((it) => it.level === "safe").slice(0, i + 1).reduce((s, it) => s + it.size, 0))}`;
        }
        await sleep(1400);
        del.classList.add("press");
        await sleep(160);
        del.classList.remove("press");
        safeRows.forEach((li) => li.classList.add("gone"));
        status.textContent = "Deleting…";
        label.textContent = "freed";
        await tween(0, safeSum, 900, (v) => (total.textContent = fmt(v)));
        status.textContent = `Freed ${fmt(safeSum)} · no confirmation needed`;
        await sleep(3600);
      }
    };

    if (reduced) {
      finalState();
    } else {
      // Start when visible; the hero is usually visible at once.
      const io = new IntersectionObserver((entries) => {
        if (entries.some((e) => e.isIntersecting)) { io.disconnect(); run(); }
      });
      io.observe(scan);
    }
  }

  // ------------------------------------------------------------------ Code blocks get a copy button
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

  // ------------------------------------------------------------------ "On this page" follows the reader
  const tocLinks = [...document.querySelectorAll(".doc-toc a[href^='#']")];
  if (tocLinks.length) {
    const headings = tocLinks.map((a) => document.getElementById(decodeURIComponent(a.hash.slice(1)))).filter(Boolean);
    const update = () => {
      const current = headings.filter((h) => h.getBoundingClientRect().top < 140).pop() || headings[0];
      tocLinks.forEach((a) => a.classList.toggle("active", a.hash.slice(1) === current?.id));
    };
    addEventListener("scroll", update, { passive: true });
    update();
  }

  // ------------------------------------------------------------------ ⌘K search
  const dialog = document.querySelector("[data-search]");
  const input = document.querySelector("[data-search-input]");
  const results = document.querySelector("[data-search-results]");
  let index = null, selected = 0, lastFocus = null;
  const escapeHTML = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const highlight = (text, words) => {
    let out = escapeHTML(text);
    words.forEach((w) => { out = out.replace(new RegExp(`(${w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "ig"), "<mark>$1</mark>"); });
    return out;
  };
  const snippet = (text, word) => {
    const at = text.toLowerCase().indexOf(word);
    return at < 60 ? text.slice(0, 160) : "…" + text.slice(at - 50, at + 110);
  };
  const renderResults = () => {
    if (!index) return;
    const words = input.value.toLowerCase().split(/\s+/).filter(Boolean);
    selected = 0;
    if (!words.length) { results.innerHTML = '<li class="search-empty">Type to search the docs.</li>'; return; }
    const found = index.map((entry) => {
      const title = entry.title.toLowerCase(), text = entry.text.toLowerCase();
      if (!words.every((w) => title.includes(w) || text.includes(w))) return null;
      return { entry, score: words.reduce((s, w) => s + (title.includes(w) ? 10 : 0) + (title.startsWith(w) ? 5 : 0), 0) };
    }).filter(Boolean).sort((a, b) => b.score - a.score).slice(0, 12);
    if (!found.length) { results.innerHTML = `<li class="search-empty">No results for “${escapeHTML(input.value)}”.</li>`; return; }
    results.innerHTML = found.map(({ entry }, i) =>
      `<li><a href="${entry.url}" role="option" aria-selected="${i === 0}"><small>${escapeHTML(entry.page)}</small>` +
      `<strong>${highlight(entry.title, words)}</strong><p>${highlight(snippet(entry.text, words[0]), words)}</p></a></li>`).join("");
  };
  const open = async () => {
    lastFocus = document.activeElement;
    dialog.hidden = false;
    input.value = "";
    input.focus();
    if (!index) { try { index = await (await fetch("search-index.json")).json(); } catch (e) { index = []; } }
    renderResults();
  };
  const close = () => { dialog.hidden = true; lastFocus?.focus(); };
  document.querySelectorAll("[data-search-open]").forEach((b) => b.addEventListener("click", open));
  document.querySelectorAll("[data-search-close]").forEach((b) => b.addEventListener("click", close));
  input?.addEventListener("input", renderResults);
  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { event.preventDefault(); dialog.hidden ? open() : close(); return; }
    if (event.key === "/" && dialog.hidden && !/input|textarea/i.test(document.activeElement.tagName)) { event.preventDefault(); open(); return; }
    if (dialog.hidden) return;
    const links = [...results.querySelectorAll("a")];
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
