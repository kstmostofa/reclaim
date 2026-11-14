#!/usr/bin/env python3
"""Builds the documentation website from site/ into docs/, where GitHub Pages serves it.

    python3 site/build.py

Pages are HTML fragments in site/pages/ with a short header of `key: value` lines ended by `---`.
In page text, {{icon:name}} inlines an icon, and {{app}}, {{repo}}, {{download}} and {{site}} expand to the
values below. Uses only the Python standard library.
"""

from __future__ import annotations

import datetime
import html
import json
import re
import shutil
import struct
from pathlib import Path

from icons import svg

# Change these when the app is renamed or the site moves.
APP = "Reclaim"
SITE = "https://kstmostofa.github.io/reclaim"
REPO = "https://github.com/kstmostofa/reclaim"
DOWNLOAD = f"{REPO}/releases/latest"
TAGLINE = "Free, open-source Mac storage cleaner for developers"
AUTHOR = "Md. Mostafijur Rahman"
VERSION = "0.1.0"

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / "docs"

# The docs sidebar: (section, [slugs]).
DOC_NAV = [
    ("Get started", ["install", "guide"]),
    ("Features", ["explore", "docker", "system", "automation"]),
    ("Reference", ["settings", "what-it-finds", "faq"]),
]


# ---------------------------------------------------------------------------------------------------------
# Pages


class Page:
    def __init__(self, path: Path):
        text = path.read_text()
        header, _, body = text.partition("\n---\n")
        self.meta = {}
        for line in header.strip().splitlines():
            key, _, value = line.partition(":")
            self.meta[key.strip()] = value.strip()
        self.slug = path.stem
        self.body = body
        self.title = self.meta["title"]
        self.description = self.meta["description"]
        self.nav_title = self.meta.get("nav", self.title)
        self.icon = self.meta.get("icon", "book")
        self.layout = self.meta.get("layout", "doc")

    @property
    def filename(self) -> str:
        return "index.html" if self.slug == "index" else f"{self.slug}.html"

    @property
    def url(self) -> str:
        return f"{SITE}/" if self.slug == "index" else f"{SITE}/{self.filename}"


def expand(text: str) -> str:
    def icon(match: re.Match) -> str:
        name, _, size = match.group(1).partition(":")
        return svg(name, int(size) if size else 20)

    text = re.sub(r"\{\{icon:([a-z0-9:-]+)\}\}", icon, text)
    for key, value in {"app": APP, "repo": REPO, "download": DOWNLOAD, "site": SITE, "version": VERSION}.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def png_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", data[16:24])


def finish_images(text: str) -> str:
    """Adds width, height and lazy loading to screenshots, so pages do not jump as images arrive."""

    def fix(match: re.Match) -> str:
        tag = match.group(0)
        src = re.search(r'src="([^"]+)"', tag).group(1)
        if "width=" not in tag and (size := png_size(ROOT / "static" / src)):
            tag = tag.replace("<img ", f'<img width="{size[0]}" height="{size[1]}" ', 1)
        if "loading=" not in tag:
            tag = tag.replace("<img ", '<img loading="lazy" decoding="async" ', 1)
        return tag

    return re.sub(r"<img [^>]+>", fix, text)


def strip_tags(text: str) -> str:
    return html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text))).strip()


def anchors(body: str) -> tuple[str, list[tuple[int, str, str]]]:
    """Adds a link to every h2 and h3 with an id, and returns the outline."""
    outline = []

    def add(match: re.Match) -> str:
        level, ident, inner = int(match.group(1)), match.group(2), match.group(3)
        outline.append((level, ident, strip_tags(inner)))
        link = f'<a class="anchor" href="#{ident}" aria-label="Link to this section">{svg("link", 16)}</a>'
        return f'<h{level} id="{ident}">{inner}{link}</h{level}>'

    body = re.sub(r'<h([23]) id="([^"]+)">(.*?)</h\1>', add, body, flags=re.S)
    return body, outline


def sections_for_search(page: Page, body: str) -> list[dict]:
    """One search entry per section: its heading, link and the start of its text."""
    entries = []
    parts = re.split(r'(<h[23] id="[^"]+">.*?</h[23]>)', body, flags=re.S)
    current = {"title": page.nav_title, "url": page.filename, "page": page.nav_title, "text": ""}
    for part in parts:
        heading = re.match(r'<h[23] id="([^"]+)">(.*?)</h[23]>', part, flags=re.S)
        if heading:
            entries.append(current)
            current = {"title": strip_tags(heading.group(2)), "url": f"{page.filename}#{heading.group(1)}",
                       "page": page.nav_title, "text": ""}
        else:
            current["text"] += " " + strip_tags(part)
    entries.append(current)
    for entry in entries:
        # Enough to match on; the search shows a short snippet around the match.
        entry["text"] = entry["text"].strip()[:3000]
    return [e for e in entries if e["title"]]


# ---------------------------------------------------------------------------------------------------------
# Structured data


def json_ld(data: dict | list) -> str:
    return f'<script type="application/ld+json">{json.dumps(data, ensure_ascii=False)}</script>'


def software_application() -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": APP,
        "description": f"{APP} scans your whole Mac, explains what is safe to delete — build caches, node_modules, "
                       "app caches, Docker leftovers, duplicates — and removes what you tick in one click.",
        "applicationCategory": "UtilitiesApplication",
        "operatingSystem": "macOS 14 or later",
        "softwareVersion": VERSION,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "license": "https://opensource.org/licenses/MIT",
        "downloadUrl": DOWNLOAD,
        "codeRepository": REPO,
        "screenshot": f"{SITE}/screenshots/overview.png",
        "url": f"{SITE}/",
        "author": {"@type": "Person", "name": AUTHOR},
    }


def breadcrumbs(page: Page, section: str) -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": APP, "item": f"{SITE}/"},
            {"@type": "ListItem", "position": 2, "name": section,
             "item": f"{SITE}/{next(slugs for name, slugs in DOC_NAV if name == section)[0]}.html"},
            {"@type": "ListItem", "position": 3, "name": page.nav_title, "item": page.url},
        ],
    }


def faq_page(body: str) -> dict | None:
    questions = re.findall(r"<details[^>]*>\s*<summary>(.*?)</summary>(.*?)</details>", body, flags=re.S)
    if not questions:
        return None
    return {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {"@type": "Question", "name": strip_tags(q),
             "acceptedAnswer": {"@type": "Answer", "text": strip_tags(a)}}
            for q, a in questions
        ],
    }


# ---------------------------------------------------------------------------------------------------------
# Layout


def head(page: Page, extra_ld: list[dict]) -> str:
    title = f"{APP} — {TAGLINE}" if page.slug == "index" else f"{page.title} · {APP}"
    image = f"{SITE}/assets/og-image.png"
    ld = "".join(json_ld(d) for d in extra_ld)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(page.description)}">
<link rel="canonical" href="{page.url}">
<meta name="author" content="{AUTHOR}">
<meta name="robots" content="index, follow">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0d0d14" media="(prefers-color-scheme: dark)">
<meta name="color-scheme" content="light dark">
<meta property="og:type" content="{'website' if page.slug == 'index' else 'article'}">
<meta property="og:site_name" content="{APP}">
<meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(page.description)}">
<meta property="og:url" content="{page.url}">
<meta property="og:image" content="{image}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="{APP}: {TAGLINE}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{html.escape(title)}">
<meta name="twitter:description" content="{html.escape(page.description)}">
<meta name="twitter:image" content="{image}">
<link rel="icon" href="assets/favicon.svg" type="image/svg+xml">
<link rel="icon" href="assets/favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="assets/apple-touch-icon.png">
<link rel="manifest" href="site.webmanifest">
<link rel="sitemap" type="application/xml" href="sitemap.xml">
<link rel="stylesheet" href="assets/style.css">
<script>try{{var t=localStorage.getItem("theme");if(t)document.documentElement.dataset.theme=t}}catch(e){{}}</script>
{ld}
</head>"""


def logo() -> str:
    return (f'<a class="brand" href="index.html" aria-label="{APP} home">'
            f'<img src="assets/favicon.svg" width="28" height="28" alt="">'
            f'<span>{APP}</span></a>')


def site_header(active: str) -> str:
    def link(href: str, label: str, key: str) -> str:
        current = ' aria-current="page"' if key == active else ""
        return f'<a href="{href}"{current}>{label}</a>'

    return f"""<a class="skip" href="#content">Skip to content</a>
<header class="site-header">
  <div class="header-inner">
    {logo()}
    <nav class="top-nav" aria-label="Main">
      {link("guide.html", "Docs", "docs")}
      {link("what-it-finds.html", "What it finds", "what-it-finds")}
      {link("faq.html", "FAQ", "faq")}
    </nav>
    <div class="header-actions">
      <button class="search-button" type="button" data-search-open aria-label="Search the docs">
        {svg("search", 16)}<span>Search</span><kbd>⌘K</kbd>
      </button>
      <button class="icon-button" type="button" data-theme-toggle aria-label="Switch light or dark mode">
        <span class="when-light">{svg("moon", 18)}</span><span class="when-dark">{svg("sun", 18)}</span>
      </button>
      <a class="icon-button" href="{REPO}" aria-label="{APP} on GitHub">{svg("github", 18)}</a>
      <a class="button button-primary button-small hide-mobile" href="{DOWNLOAD}">{svg("download", 16)}Download</a>
      <button class="icon-button show-mobile" type="button" data-menu-toggle aria-label="Open menu" aria-expanded="false">
        {svg("menu", 20)}
      </button>
    </div>
  </div>
</header>"""


def site_footer() -> str:
    year = datetime.date.today().year
    return f"""<footer class="site-footer">
  <div class="footer-inner">
    <div class="footer-brand">
      {logo()}
      <p>{TAGLINE}. Free under the MIT License.</p>
    </div>
    <div class="footer-columns">
      <div><h2>Product</h2><a href="{DOWNLOAD}">Download</a><a href="install.html">Install</a><a href="{REPO}/releases">Release notes</a></div>
      <div><h2>Docs</h2><a href="guide.html">Using {APP}</a><a href="what-it-finds.html">What it finds</a><a href="faq.html">FAQ</a></div>
      <div><h2>Project</h2><a href="{REPO}">Source code</a><a href="{REPO}/issues">Report a problem</a><a href="{REPO}/blob/main/LICENSE">License</a></div>
    </div>
  </div>
  <div class="footer-bottom">
    <span>© {year} {AUTHOR}</span>
    <span>Icons in the style of <a href="https://lucide.dev">Lucide</a> (ISC)</span>
  </div>
</footer>
<div class="search-dialog" data-search hidden>
  <div class="search-backdrop" data-search-close></div>
  <div class="search-panel" role="dialog" aria-modal="true" aria-label="Search the docs">
    <div class="search-field">{svg("search", 18)}<input type="search" placeholder="Search the docs" aria-label="Search the docs" autocomplete="off" data-search-input><kbd>Esc</kbd></div>
    <ul class="search-results" data-search-results role="listbox"></ul>
  </div>
</div>
<script src="assets/app.js" defer></script>
</body>
</html>"""


def doc_sidebar(current: Page, pages: dict[str, Page]) -> str:
    groups = []
    for section, slugs in DOC_NAV:
        items = ""
        for s in slugs:
            mark = ' aria-current="page"' if s == current.slug else ""
            items += f'<li><a href="{pages[s].filename}"{mark}>{svg(pages[s].icon, 16)}{pages[s].nav_title}</a></li>'

        groups.append(f'<div class="sidebar-group"><h2>{section}</h2><ul>{items}</ul></div>')
    return f'<nav class="doc-sidebar" aria-label="Documentation" data-menu>{"".join(groups)}</nav>'


def doc_toc(outline: list[tuple[int, str, str]]) -> str:
    if not outline:
        return ""
    items = "".join(f'<li class="toc-l{level}"><a href="#{ident}">{html.escape(text)}</a></li>'
                    for level, ident, text in outline)
    return f'<aside class="doc-toc" aria-label="On this page"><h2>On this page</h2><ul>{items}</ul></aside>'


def render_doc(page: Page, pages: dict[str, Page], order: list[str]) -> tuple[str, list[dict]]:
    body, outline = anchors(finish_images(expand(page.body)))
    section = next(name for name, slugs in DOC_NAV if page.slug in slugs)
    index = order.index(page.slug)
    prev_page = pages[order[index - 1]] if index > 0 else None
    next_page = pages[order[index + 1]] if index + 1 < len(order) else None
    pager = '<nav class="pager" aria-label="Previous and next">'
    pager += (f'<a class="pager-prev" href="{prev_page.filename}"><span>{svg("chevron-left", 16)}Previous</span>'
              f'<strong>{prev_page.nav_title}</strong></a>') if prev_page else "<span></span>"
    pager += (f'<a class="pager-next" href="{next_page.filename}"><span>Next{svg("chevron-right", 16)}</span>'
              f'<strong>{next_page.nav_title}</strong></a>') if next_page else "<span></span>"
    pager += "</nav>"

    ld = [breadcrumbs(page, section), {
        "@context": "https://schema.org", "@type": "TechArticle", "headline": page.title,
        "description": page.description, "url": page.url, "author": {"@type": "Person", "name": AUTHOR},
        "about": {"@type": "SoftwareApplication", "name": APP, "operatingSystem": "macOS"},
    }]
    if faq := faq_page(body):
        ld.append(faq)

    active = page.slug if page.slug in ("what-it-finds", "faq") else "docs"
    out = head(page, ld) + "\n<body>\n" + site_header(active) + f"""
<div class="doc-layout">
  {doc_sidebar(page, pages)}
  <main class="doc-main" id="content">
    <nav class="crumbs" aria-label="Breadcrumb"><a href="index.html">{APP}</a>{svg("chevron-right", 14)}<span>{section}</span>{svg("chevron-right", 14)}<span aria-current="page">{page.nav_title}</span></nav>
    <article class="prose">
      <h1>{page.title}</h1>
      <p class="lead">{page.meta.get("lead", page.description)}</p>
      {body}
    </article>
    <div class="doc-meta"><a href="{REPO}/edit/main/site/pages/{page.slug}.html">{svg("code", 16)}Edit this page on GitHub</a></div>
    {pager}
  </main>
  {doc_toc(outline)}
</div>
""" + site_footer()
    return out, sections_for_search(page, body)


def render_home(page: Page) -> tuple[str, list[dict]]:
    body = finish_images(expand(page.body))
    ld = [software_application(), {
        "@context": "https://schema.org", "@type": "WebSite", "name": APP, "url": f"{SITE}/",
        "description": page.description,
    }]
    out = head(page, ld) + "\n<body class=\"home\">\n" + site_header("home") + \
        f'\n<main id="content">\n{body}\n</main>\n' + site_footer()
    return out, [{"title": f"{APP} home", "url": "index.html", "page": "Home", "text": strip_tags(body)[:400]}]


def render_404() -> str:
    page = Page.__new__(Page)
    page.slug, page.title, page.nav_title = "404", "Page not found", "Not found"
    page.description = "This page does not exist."
    page.meta = {}
    return head(page, []).replace('<meta name="robots" content="index, follow">', '<meta name="robots" content="noindex">') + \
        "\n<body>\n" + site_header("") + f"""
<main id="content" class="not-found">
  <p class="eyebrow">404</p>
  <h1>This page is not here</h1>
  <p>It may have moved when the docs were reorganised.</p>
  <div class="hero-actions"><a class="button button-primary" href="index.html">Go home</a><a class="button" href="guide.html">Read the docs</a></div>
</main>
""" + site_footer()


# ---------------------------------------------------------------------------------------------------------


def main() -> None:
    pages = {p.stem: Page(p) for p in sorted((ROOT / "pages").glob("*.html"))}
    order = [slug for _, slugs in DOC_NAV for slug in slugs]
    missing = [s for s in order if s not in pages]
    assert not missing, f"Missing pages: {missing}"

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    shutil.copytree(ROOT / "assets", OUT / "assets")
    for item in (ROOT / "static").iterdir():
        if item.is_dir():
            shutil.copytree(item, OUT / item.name)
        else:
            shutil.copy(item, OUT / item.name)
    (OUT / ".nojekyll").touch()

    search = []
    for slug, page in pages.items():
        if page.layout == "home":
            text, entries = render_home(page)
        else:
            text, entries = render_doc(page, pages, order)
        (OUT / page.filename).write_text(text)
        search += entries
    (OUT / "404.html").write_text(render_404())
    (OUT / "search-index.json").write_text(json.dumps(search, ensure_ascii=False))

    today = datetime.date.today().isoformat()
    urls = [pages["index"]] + [pages[s] for s in order]
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "".join(f"  <url><loc>{p.url}</loc><lastmod>{today}</lastmod>"
                  f"<priority>{'1.0' if p.slug == 'index' else '0.7'}</priority></url>\n" for p in urls)
        + "</urlset>\n")
    (OUT / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n")
    (OUT / "site.webmanifest").write_text(json.dumps({
        "name": APP, "short_name": APP, "description": TAGLINE, "start_url": "./", "display": "standalone",
        "background_color": "#ffffff", "theme_color": "#5856d6",
        "icons": [{"src": "assets/apple-touch-icon.png", "sizes": "180x180", "type": "image/png"},
                  {"src": "assets/favicon.svg", "sizes": "any", "type": "image/svg+xml"}],
    }, indent=2))
    print(f"Built {len(pages)} pages into {OUT}")


if __name__ == "__main__":
    main()
