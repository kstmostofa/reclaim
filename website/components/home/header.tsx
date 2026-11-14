'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { useTheme } from 'next-themes';
import { useSearchContext } from 'fumadocs-ui/contexts/search';
import { Download, Menu, Moon, Search, Sun, X } from 'lucide-react';
import { GitHubIcon, LogoMark } from '@/components/logo';
import { appName, downloadUrl, repoUrl } from '@/lib/shared';
import { cn } from '@/lib/cn';

const links = [
  { label: 'Docs', href: '/docs' },
  { label: 'What it finds', href: '/docs/what-it-finds' },
  { label: 'FAQ', href: '/docs/faq' },
];

const iconButton =
  'grid size-9 place-items-center rounded-full text-fd-muted-foreground transition-colors hover:bg-fd-accent hover:text-fd-foreground';

/** A pill that floats over the landing page and tightens once the page scrolls. */
export function FloatingHeader() {
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const { setOpenSearch } = useSearchContext();
  const { resolvedTheme, setTheme } = useTheme();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <div className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center px-3 pt-3 md:pt-4">
      <motion.header
        initial={{ y: -24, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
        className={cn(
          'pointer-events-auto w-full max-w-5xl rounded-full border transition-[background-color,box-shadow,border-color,max-width] duration-500',
          scrolled
            ? 'max-w-4xl border-fd-border bg-fd-background/75 shadow-[0_10px_40px_-12px_rgb(0_0_0/0.25)] backdrop-blur-xl dark:shadow-[0_10px_40px_-12px_rgb(0_0_0/0.8)]'
            : 'border-transparent bg-fd-background/40 backdrop-blur-md',
        )}
      >
        <nav className="flex h-14 items-center gap-2 pr-2 pl-5" aria-label="Main">
          <Link href="/" className="font-display mr-4 flex items-center gap-2.5 text-[22px] leading-none font-semibold">
            <LogoMark className="size-[22px]" />
            {appName}
          </Link>

          <div className="hidden items-center md:flex">
            {links.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                className="font-display rounded-full px-3.5 py-1.5 text-[17px] font-medium text-fd-muted-foreground transition-colors hover:bg-fd-accent hover:text-fd-foreground"
              >
                {l.label}
              </Link>
            ))}
          </div>

          <span className="flex-1" />

          <button type="button" onClick={() => setOpenSearch(true)} aria-label="Search the docs" className={iconButton}>
            <Search className="size-[18px]" />
          </button>
          <button
            type="button"
            onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
            aria-label="Switch light or dark mode"
            className={iconButton}
          >
            <Sun className="hidden size-[18px] dark:block" />
            <Moon className="size-[18px] dark:hidden" />
          </button>
          <a href={repoUrl} aria-label={`${appName} on GitHub`} className={cn(iconButton, 'hidden sm:grid')}>
            <GitHubIcon className="size-[18px]" />
          </a>
          <a
            href={downloadUrl}
            className="font-display ml-1 hidden h-10 items-center gap-2 rounded-full bg-fd-foreground px-4.5 text-[17px] font-semibold text-fd-background transition-opacity hover:opacity-85 sm:inline-flex"
          >
            <Download className="size-4" />
            Download
          </a>
          <button type="button" onClick={() => setMenu((m) => !m)} aria-label="Menu" aria-expanded={menu} className={cn(iconButton, 'md:hidden')}>
            {menu ? <X className="size-5" /> : <Menu className="size-5" />}
          </button>
        </nav>

        <AnimatePresence>
          {menu && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
              className="overflow-hidden md:hidden"
            >
              <div className="grid gap-1 px-3 pb-4">
                {links.map((l) => (
                  <Link key={l.href} href={l.href} onClick={() => setMenu(false)} className="font-display rounded-2xl px-4 py-2.5 text-xl font-medium hover:bg-fd-accent">
                    {l.label}
                  </Link>
                ))}
                <a href={downloadUrl} className="font-display mt-2 flex h-12 items-center justify-center gap-2 rounded-full bg-fd-foreground text-lg font-semibold text-fd-background">
                  <Download className="size-4" />
                  Download for Mac
                </a>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.header>
    </div>
  );
}
