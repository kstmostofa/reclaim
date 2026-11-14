// Copies the static export into ../docs, which GitHub Pages serves. Run through `npm run export`.
import { cpSync, rmSync, writeFileSync, existsSync } from 'node:fs';

const out = new URL('../out/', import.meta.url);
const docs = new URL('../../docs/', import.meta.url);
if (!existsSync(out)) throw new Error('No out/ folder; run next build first.');
rmSync(docs, { recursive: true, force: true });
cpSync(out, docs, { recursive: true });
// Tells GitHub Pages not to run Jekyll, which would hide the _next folder.
writeFileSync(new URL('.nojekyll', docs), '');
// The custom domain GitHub Pages serves the site on.
writeFileSync(new URL('CNAME', docs), 'reclaim.mostofa.me\n');
console.log('Published the site to docs/');
