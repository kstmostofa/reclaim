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
  // The theme is only known after hydration; until then neither half of the switch is marked.
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

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
          'border-fd-border backdrop-blur-xl backdrop-saturate-150',
          'shadow-[inset_0_1px_0_rgb(255_255_255/0.5),0_8px_30px_-14px_rgb(0_0_0/0.18)] dark:shadow-[inset_0_1px_0_rgb(255_255_255/0.06),0_8px_30px_-14px_rgb(0_0_0/0.7)]',
          scrolled ? 'max-w-4xl bg-fd-background/80' : 'bg-fd-background/45',
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

          <button
            type="button"
            onClick={() => setOpenSearch(true)}
            className="hidden h-9 w-52 items-center gap-2 rounded-full border border-fd-border bg-fd-secondary/50 pr-1.5 pl-3 text-[16px] text-fd-muted-foreground transition-colors hover:bg-fd-accent hover:text-fd-foreground lg:flex"
          >
            <Search className="size-4" />
            <span className="flex-1 text-left">Search</span>
            <span className="flex gap-0.5">
              <kbd className="rounded-md border border-fd-border bg-fd-background px-1.5 font-mono text-[11px] leading-5">⌘</kbd>
              <kbd className="rounded-md border border-fd-border bg-fd-background px-1.5 font-mono text-[11px] leading-5">K</kbd>
            </span>
          </button>
          <button type="button" onClick={() => setOpenSearch(true)} aria-label="Search the docs" className={cn(iconButton, 'lg:hidden')}>
            <Search className="size-[18px]" />
          </button>
          <div className="flex items-center rounded-full border border-fd-border p-0.5" role="group" aria-label="Theme">
            {([['light', Sun], ['dark', Moon]] as const).map(([mode, Icon]) => (
              <button
                key={mode}
                type="button"
                onClick={() => setTheme(mode)}
                aria-label={mode === 'light' ? 'Light mode' : 'Dark mode'}
                aria-pressed={mounted && resolvedTheme === mode}
                className={cn(
                  'grid size-7 place-items-center rounded-full transition-colors',
                  mounted && resolvedTheme === mode ? 'bg-fd-accent text-fd-foreground' : 'text-fd-muted-foreground hover:text-fd-foreground',
                )}
              >
                <Icon className="size-4" />
              </button>
            ))}
          </div>
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
