import type { Metadata, Viewport } from 'next';
import { Inter, JetBrains_Mono, Khand } from 'next/font/google';
import { Provider } from '@/components/provider';
import { lensMap } from '@/lib/lens';
import { appName, author, siteUrl, tagline } from '@/lib/shared';
import './global.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-inter', display: 'swap' });
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono', display: 'swap' });
// Headings, display type and interface text; long-form reading stays in Inter.
const khand = Khand({ subsets: ['latin'], weight: ['400', '500', '600', '700'], variable: '--font-khand', display: 'swap' });

const description =
  'Reclaim finds build caches, node_modules, app caches, Docker leftovers and duplicate files on your Mac, explains what is safe to delete, and frees the space in one click.';

export const metadata: Metadata = {
  metadataBase: new URL(`${siteUrl}/`),
  title: { default: `${appName} — ${tagline}`, template: `%s · ${appName}` },
  description,
  applicationName: appName,
  authors: [{ name: author }],
  keywords: ['mac cleaner', 'disk space', 'node_modules', 'Xcode DerivedData', 'Docker cleanup', 'developer tools', 'macOS', 'open source'],
  alternates: { canonical: './' },
  openGraph: { type: 'website', siteName: appName, title: `${appName} — ${tagline}`, description, url: './' },
  twitter: { card: 'summary_large_image', title: `${appName} — ${tagline}`, description },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#000000' },
  ],
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={`${inter.variable} ${mono.variable} ${khand.variable}`} suppressHydrationWarning>
      <body className="flex min-h-screen flex-col font-sans antialiased">
        {/* The Liquid Glass lens: bends what is behind the glass near its edges only, like a thick lens. */}
        <svg width="0" height="0" className="absolute" aria-hidden="true">
          <filter id="liquid-lens" x="0" y="0" width="1" height="1" primitiveUnits="objectBoundingBox" colorInterpolationFilters="sRGB">
            <feImage href={lensMap} x="0" y="0" width="1" height="1" preserveAspectRatio="none" result="map" />
            <feDisplacementMap in="SourceGraphic" in2="map" scale="0.05" xChannelSelector="R" yChannelSelector="G" />
          </filter>
        </svg>
        <Provider>{children}</Provider>
      </body>
    </html>
  );
}
