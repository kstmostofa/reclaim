import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { ImageResponse } from 'next/og';
import { notFound } from 'next/navigation';
import { source } from '@/lib/source';
import { appName, domain, getPageImageUrl } from '@/lib/shared';

export const revalidate = false;

// The social image for each docs page, in the site's look: near-black, the Wedge mark, the title in Khand.
export async function GET(_req: Request, { params }: RouteContext<'/og/docs/[...slug]'>) {
  const { slug } = await params;
  const page = source.getPage(slug.slice(0, -1));
  if (!page) notFound();

  const fonts = join(process.cwd(), 'assets/fonts');
  const [semibold, regular] = await Promise.all([
    readFile(join(fonts, 'Khand-SemiBold.ttf')),
    readFile(join(fonts, 'Khand-Regular.ttf')),
  ]);

  return new ImageResponse(
    (
      <div style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', padding: '64px 72px', background: '#0b0b0d', color: '#f5f5f7', fontFamily: 'Khand' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <div style={{ width: 64, height: 64, borderRadius: 15, background: '#17171c', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px solid rgba(255,255,255,0.1)' }}>
            <svg width="40" height="40" viewBox="232 232 560 560">
              <path d="M495.7 528.3H745.7A250 250 0 1 1 495.7 278.3Z" fill="#ffffff" />
              <path d="M528.3 495.7V245.7A250 250 0 0 1 778.3 495.7Z" fill="#5856D6" />
            </svg>
          </div>
          <div style={{ fontSize: 40, fontWeight: 600 }}>{appName}</div>
          <div style={{ fontSize: 30, color: '#8e8e96', marginLeft: 8 }}>Docs</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ fontSize: 92, fontWeight: 600, lineHeight: 0.95, letterSpacing: -1 }}>{page.data.title}</div>
          <div style={{ fontSize: 36, color: '#b4b4bd', lineHeight: 1.3, maxWidth: 1000 }}>{page.data.description}</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontSize: 28, color: '#8e8e96' }}>
          <div style={{ width: 48, height: 6, borderRadius: 3, background: '#5856D6' }} />
          {domain}
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts: [
        { name: 'Khand', data: semibold, weight: 600, style: 'normal' },
        { name: 'Khand', data: regular, weight: 400, style: 'normal' },
      ],
    },
  );
}

export function generateStaticParams() {
  return source.getPages().map((page) => ({
    lang: page.locale,
    slug: getPageImageUrl(page).segments,
  }));
}
