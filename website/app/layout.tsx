import type { Metadata, Viewport } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';
import { Provider } from '@/components/provider';
import { appName, author, siteUrl, tagline } from '@/lib/shared';
import './global.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-inter', display: 'swap' });
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono', display: 'swap' });

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
    <html lang="en" className={`${inter.variable} ${mono.variable}`} suppressHydrationWarning>
      <body className="flex min-h-screen flex-col font-sans antialiased">
        <Provider>{children}</Provider>
      </body>
    </html>
  );
}
