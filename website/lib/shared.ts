import { createGetUrl } from 'fumadocs-core/source';

// Change these when the app is renamed or the site moves.
export const appName = 'Reclaim';
export const tagline = 'Free, open-source Mac storage cleaner for developers';
export const version = '1.0.0';
export const author = 'Md. Mostafijur Rahman';
export const gitConfig = { user: 'kstmostofa', repo: 'reclaim', branch: 'main' };
export const repoUrl = `https://github.com/${gitConfig.user}/${gitConfig.repo}`;
/** The latest release's disk image, downloaded directly; the release page lists every file. */
export const downloadUrl = `${repoUrl}/releases/latest/download/Reclaim.dmg`;
export const releasesUrl = `${repoUrl}/releases/latest`;

/** The site is served at the root of its own domain; set NEXT_PUBLIC_BASE_PATH to host it under a folder. */
export const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
export const domain = 'reclaim.mostofa.me';
export const siteUrl = `https://${domain}${basePath}`;

/** Prefixes public files (images, the search index) with the base path, which Next does not do for plain URLs. */
export const asset = (path: string) => `${basePath}${path}`;

export const docsRoute = '/docs';
export const docsImageRoute = '/og/docs';
export const docsContentRoute = '/llms.mdx/docs';

const getContentUrl = createGetUrl(docsContentRoute);

export function getPageMarkdownUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, 'content.md'];
  return { segments, url: getContentUrl(segments, page.locale) };
}

const getImageUrl = createGetUrl(docsImageRoute);

export function getPageImageUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, 'image.png'];
  return { segments, url: getImageUrl(segments, page.locale) };
}
