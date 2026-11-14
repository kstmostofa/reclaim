# Reclaim website

The landing page and documentation, built with Next.js, Fumadocs, Tailwind and Motion, and exported as
static files to `../docs` for GitHub Pages.

```sh
npm install
npm run dev       # http://localhost:3000, no base path
npm run export    # builds for https://reclaim.mostofa.me and copies the result to ../docs
```

- Docs pages are MDX in `content/docs/`; their order and sections are in `content/docs/meta.json`.
- The landing page is `app/(home)/page.tsx` with its sections in `components/home/`.
- The app name, repository, version and site URL live in `lib/shared.ts`. GitHub Pages serves the site at
  https://reclaim.mostofa.me (the export writes the `CNAME` file); set `NEXT_PUBLIC_BASE_PATH` to host it under a
  folder instead.
- Screenshots are in `public/screenshots/` and must not show personal file paths. Icons and the social image come
  from `../brand/make_brand.py`.
