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
  document.querySelectorAll(".tile, .card-link, .card").forEach((card) =>
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

  // ------------------------------------------------------------------ The app replica in the hero
  const app = document.querySelector("[data-app]");
  if (app) {
    const rows = [
      { name: "DerivedData/Storefront-ghxqv", where: "~/Library/Developer/Xcode", size: 6.89, when: "3 Nov 2026" },
      { name: ".next", where: "~/Projects/storefront", size: 2.14, when: "11 Nov 2026" },
      { name: "target", where: "~/Projects/engine", size: 1.92, when: "28 Oct 2026" },
      { name: ".turbo", where: "~/Projects/monorepo", size: 0.64, when: "9 Nov 2026" },
      { name: "build/intermediates", where: "~/Projects/android/app", size: 0.41, when: "30 Oct 2026" },
      { name: "__pycache__", where: "~/Projects/ml-tools", size: 0.096, when: "12 Nov 2026" },
    ];
    const total = rows.reduce((s, r) => s + r.size, 0);
    const $ = (sel) => app.querySelector(sel);
    const list = $("[data-rows]"), sub = $("[data-sub]"), bar = $("[data-bar]"), del = $("[data-del]");
    const toast = $("[data-toast]"), cursor = $("[data-cursor]"), selSafe = $("[data-selectsafe]"), build = $("[data-build]");
    const sizes = [...app.querySelectorAll("[data-to]")];
    const tick = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
    const folder = '<svg class="folder" viewBox="0 0 22 18"><path d="M1 3.2C1 2 2 1 3.2 1h5l2 2.2h8.6C20 3.2 21 4.2 21 5.4v9.4c0 1.2-1 2.2-2.2 2.2H3.2C2 17 1 16 1 14.8z" fill="#4aa3f2"/><path d="M1 6h20v8.8c0 1.2-1 2.2-2.2 2.2H3.2C2 17 1 16 1 14.8z" fill="#6bb8f7"/></svg>';
    const gb = (v) => (v >= 1 ? v.toFixed(2) + " GB" : Math.round(v * 1000) + " MB");
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
    const tween = (ms, fn) => new Promise((done) => {
      const t0 = performance.now();
      const step = (now) => { const t = Math.min(1, (now - t0) / ms); fn(1 - Math.pow(1 - t, 3)); t < 1 ? requestAnimationFrame(step) : done(); };
      requestAnimationFrame(step);
    });

    // Positions inside the window, unaffected by its tilt.
    const at = (el) => { let x = 0, y = 0; for (let n = el; n && n !== app; n = n.offsetParent) { x += n.offsetLeft; y += n.offsetTop; } return { x, y, w: el.offsetWidth, h: el.offsetHeight }; };
    const moveTo = async (el) => {
      const b = at(el);
      cursor.style.transform = `translate(${b.x + b.w * 0.6}px, ${b.y + b.h * 0.55}px)`;
      await sleep(1000);
    };
    const click = async (el) => {
      cursor.classList.add("click"); el.classList.add("press");
      await sleep(160);
      cursor.classList.remove("click"); el.classList.remove("press");
    };

    const draw = () => {
      list.innerHTML = rows.map((r) =>
        `<div class="row"><span class="box">${tick}</span><span class="nm">${folder}<div><strong>${r.name}</strong><small>${r.where}</small></div></span>` +
        `<span class="size">${gb(r.size)}</span><span class="badge safe">Safe</span><span class="when">${r.when}</span></div>`).join("");
      const els = [...list.children];
      list.insertAdjacentHTML("beforeend", '<div class="empty"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg><strong>Nothing to Show</strong><span>Build Caches is clean.</span></div>');
      list.classList.remove("cleared");
      return els;
    };

    const finalState = () => {
      const els = draw();
      els.forEach((el) => el.classList.add("on", "ticked"));
      sizes.forEach((s) => (s.textContent = s.dataset.to));
      sub.textContent = `${rows.length} items · ${total.toFixed(1)} GB`;
      del.classList.remove("off");
      del.textContent = `Delete ${rows.length} items · ${total.toFixed(1)} GB`;
    };

    const loop = async () => {
      // Start just off the window's top-right, out of the way.
      cursor.style.transform = `translate(${app.offsetWidth - 120}px, ${app.offsetHeight - 160}px)`;
      while (true) {
        const els = draw();
        toast.classList.remove("on");
        del.classList.add("off");
        del.textContent = "Delete 0 items";
        sizes.forEach((s) => (s.textContent = "—"));
        sub.textContent = "Scanning…";
        bar.style.transition = "none"; bar.style.width = "0"; bar.style.opacity = "1";
        await sleep(500);

        // Scan: progress, file counter, sidebar sizes and rows.
        bar.style.transition = "width 3.4s cubic-bezier(.4,.1,.3,1)"; bar.style.width = "100%";
        tween(3400, (t) => (sub.textContent = `Scanning · ${Math.round(t * 2717258).toLocaleString("en-US")} files`));
        sizes.forEach((s, i) => setTimeout(() => (s.textContent = s.dataset.to), 500 + i * 300));
        for (const el of els) { await sleep(480); el.classList.add("on"); }
        await sleep(700);
        bar.style.transition = "opacity .5s"; bar.style.opacity = "0";
        sub.textContent = `${rows.length} items · ${total.toFixed(1)} GB`;

        // Select All Safe.
        cursor.classList.add("on");
        await moveTo(selSafe);
        await click(selSafe);
        del.classList.remove("off");
        for (const [i, el] of els.entries()) {
          await sleep(110);
          el.classList.add("ticked");
          const sum = rows.slice(0, i + 1).reduce((s, r) => s + r.size, 0);
          del.textContent = `Delete ${i + 1} ${i ? "items" : "item"} · ${sum.toFixed(1)} GB`;
        }
        await sleep(700);

        // Delete.
        await moveTo(del);
        await click(del);
        for (const el of els) { el.classList.add("out"); await sleep(90); }
        tween(700, (t) => (build.textContent = t < 1 ? gb(total * (1 - t)) : "—"));
        del.classList.add("off");
        del.textContent = "Delete 0 items";
        sub.textContent = "No items";
        list.classList.add("cleared");
        await sleep(300);
        toast.classList.add("on");
        cursor.style.transform = `translate(${app.offsetWidth - 120}px, ${app.offsetHeight - 160}px)`;
        await sleep(3800);
        cursor.classList.remove("on");
        toast.classList.remove("on");
        await sleep(600);
      }
    };

    if (reduced) {
      finalState();
    } else {
      // Tilted back at first, the window straightens as the page scrolls.
      const tilt = () => {
        const p = Math.min(1, Math.max(0, scrollY / 520));
        app.style.setProperty("--tilt", `${18 * (1 - p)}deg`);
        app.style.setProperty("--sc", `${0.94 + 0.06 * p}`);
      };
      addEventListener("scroll", tilt, { passive: true });
      tilt();
      setTimeout(loop, 1400);
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
