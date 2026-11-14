'use client';
import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { animate, motion, useInView, useReducedMotion } from 'motion/react';
import {
  ArrowRight,
  Box,
  Copy,
  Download,
  EyeOff,

  Laptop,
  Lock,
  Palette,
  ShieldCheck,
  Sparkles,
  Wrench,
  BarChart3,
  Clock,
  Plus,
} from 'lucide-react';
import { Reveal } from './reveal';
import { GitHubIcon, LogoMark } from "@/components/logo";
import { appName, asset, author, downloadUrl, releasesUrl, repoUrl } from '@/lib/shared';
import { cn } from '@/lib/cn';
import { faqs } from '@/lib/faqs';

const ease = [0.16, 1, 0.3, 1] as const;

function Kicker({ children }: { children: React.ReactNode }) {
  return (
    <p className="eyebrow mb-5 inline-flex items-center gap-2.5">
      <span className="size-1.5 rounded-[2px] bg-brand" />
      {children}
    </p>
  );
}

/* ------------------------------------------------------------------ Figures */

function CountUp({ to, suffix = '' }: { to: number; suffix?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true });
  const reduce = useReducedMotion();
  const [value, setValue] = useState(reduce ? to : 0);
  useEffect(() => {
    if (!inView || reduce) return;
    const controls = animate(0, to, { duration: 1.6, ease, onUpdate: (v) => setValue(Math.round(v)) });
    return () => controls.stop();
  }, [inView, reduce, to]);
  return (
    <span ref={ref} className="tabular-nums">
      {value}
      {suffix}
    </span>
  );
}

export function Figures() {
  const items = [
    { to: 42, label: 'places it knows to look' },
    { to: 1, suffix: ' min', label: 'to scan an entire Mac' },
    { to: 3, label: 'safety levels, only Safe pre-ticked' },
    { to: 0, label: 'network requests, ever' },
  ];
  return (
    <section className="mx-auto max-w-6xl px-6 py-24 md:py-32">
      <Reveal className="grid grid-cols-2 border-y border-fd-border md:grid-cols-4">
        {items.map((it, i) => (
          <div key={it.label} className={cn('px-5 py-10 md:px-8 md:py-12', i % 2 === 0 && 'border-r border-fd-border', i === 1 && 'md:border-r', i < 2 && 'max-md:border-b')}>
            <p className="display text-6xl md:text-7xl">
              <CountUp to={it.to} suffix={it.suffix} />
            </p>
            <p className="mt-3 text-[18px] text-fd-muted-foreground">{it.label}</p>
          </div>
        ))}
      </Reveal>
    </section>
  );
}

/* ------------------------------------------------------------------ Tools marquee */

const tools = ['Next.js', 'Nuxt', 'Turborepo', 'SvelteKit', 'Xcode', 'Gradle', 'Android Studio', 'Flutter', 'Rust', 'Python', 'npm', 'pnpm', 'Yarn', 'Composer', 'CocoaPods', 'Homebrew', 'Docker', 'OrbStack', 'Playwright', 'Go'];

export function Marquee() {
  return (
    <section className="py-16" aria-label="Developer tools Reclaim knows">
      <p className="eyebrow mb-8 text-center">Knows where developer tools leave things</p>
      <div className="overflow-hidden [mask-image:linear-gradient(90deg,transparent,#000_15%,#000_85%,transparent)]">
        <div className="marquee-track flex w-max gap-10">
          {[...tools, ...tools].map((t, i) => (
            <span key={i} aria-hidden={i >= tools.length} className="text-[20px] font-medium whitespace-nowrap text-fd-muted-foreground">
              {t}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ Features */

function Card({ className, icon: Icon, title, children, visual, href, linkText, delay = 0 }: {
  className?: string; icon: typeof Wrench; title: string; children: React.ReactNode; visual?: React.ReactNode; href?: string; linkText?: string; delay?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const onMove = (e: React.PointerEvent) => {
    const b = ref.current!.getBoundingClientRect();
    ref.current!.style.setProperty('--mx', `${e.clientX - b.left}px`);
    ref.current!.style.setProperty('--my', `${e.clientY - b.top}px`);
  };
  return (
    <Reveal delay={delay} className={className}>
      <div
        ref={ref}
        onPointerMove={onMove}
        className="glass-card group relative h-full overflow-hidden rounded-3xl p-8"
      >
        <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-100 [background:radial-gradient(500px_circle_at_var(--mx)_var(--my),color-mix(in_srgb,var(--color-fd-foreground)_6%,transparent),transparent_50%)]" />
        <span className="mb-7 grid size-11 place-items-center rounded-xl border border-fd-border bg-fd-background">
          <Icon className="size-5" strokeWidth={1.7} />
        </span>
        <h3 className="text-[27px] leading-tight font-semibold">{title}</h3>
        <p className="mt-2.5 max-w-md text-[19px] leading-relaxed text-fd-muted-foreground">{children}</p>
        {visual && <div className="mt-8">{visual}</div>}
        {href && (
          <Link href={href} className="mt-6 inline-flex items-center gap-1.5 text-[17px] font-medium">
            {linkText}
            <ArrowRight className="size-4 transition-transform group-hover:translate-x-0.5" />
          </Link>
        )}
      </div>
    </Reveal>
  );
}

function Bars() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: '-15%' });
  const bars = [
    { name: 'node_modules', w: 94, size: '14.2 GB', c: 'bg-rebuild' },
    { name: 'DerivedData', w: 46, size: '6.9 GB', c: 'bg-fd-foreground' },
    { name: 'vendor', w: 21, size: '3.1 GB', c: 'bg-rebuild' },
    { name: '.gradle', w: 14, size: '2.1 GB', c: 'bg-fd-foreground' },
    { name: '.next', w: 9, size: '1.3 GB', c: 'bg-fd-foreground' },
  ];
  return (
    <div ref={ref} className="grid gap-3.5">
      {bars.map((b, i) => (
        <div key={b.name} className="grid grid-cols-[110px_1fr_64px] items-center gap-4 text-[17px] text-fd-muted-foreground">
          <span>{b.name}</span>
          <span className="h-1.5 overflow-hidden rounded-full bg-fd-foreground/[0.07]">
            <motion.span
              className={cn('block h-full origin-left rounded-full', b.c)}
              style={{ width: `${b.w}%` }}
              initial={{ scaleX: 0 }}
              animate={{ scaleX: inView ? 1 : 0 }}
              transition={{ duration: 1.5, delay: i * 0.1, ease }}
            />
          </span>
          <span className="text-right text-fd-foreground">{b.size}</span>
        </div>
      ))}
    </div>
  );
}

function Dupes() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: '-15%' });
  return (
    <div ref={ref} className="grid gap-2 text-[17px]">
      {['photo.heic', 'photo copy.heic', 'photo 2.heic'].map((f, i) => (
        <motion.span
          key={f}
          animate={{ opacity: inView && i > 0 ? 0.3 : 1 }}
          transition={{ duration: 0.8, delay: 0.6 + i * 0.2 }}
          className={cn('flex justify-between rounded-xl border px-3.5 py-2.5', i === 0 ? 'border-brand/60' : 'border-fd-border', inView && i > 0 && 'line-through')}
        >
          {f}
          {i === 0 && <span className="text-[13px] font-semibold tracking-wider text-brand uppercase">keep</span>}
        </motion.span>
      ))}
    </div>
  );
}

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-6 py-24 md:py-36">
      <Reveal className="mb-16 max-w-3xl">
        <Kicker>Features</Kicker>
        <h2 className="display text-[clamp(3rem,6.4vw,5.5rem)]">
          Built for the way developer Macs fill up.
        </h2>
      </Reveal>
      <div className="grid gap-4 md:grid-cols-6">
        <Card className="md:col-span-4" icon={Wrench} title="Knows where junk hides" visual={<Bars />} href="/docs/what-it-finds" linkText="See every rule">
          Build output, installed dependencies and package-manager caches, found by rules written from real developer Macs.
        </Card>
        <Card className="md:col-span-2" icon={ShieldCheck} title="Three safety levels" delay={0.08}
          visual={
            <div className="grid gap-2 text-sm">
              {[['Rebuilds itself', 'Safe', 'text-safe bg-safe/10'], ['Needs a reinstall', 'Rebuild', 'text-rebuild bg-rebuild/10'], ['Your data', 'Personal', 'text-personal bg-personal/10']].map(([t, l, c]) => (
                <div key={l} className="flex items-center justify-between rounded-xl border border-fd-border px-3.5 py-3 text-fd-muted-foreground">
                  {t}
                  <span className={cn('rounded-full px-2 py-0.5 text-xs font-semibold', c)}>{l}</span>
                </div>
              ))}
            </div>
          }
        >
          Only Safe items are ever ticked for you.
        </Card>
        <Card className="md:col-span-2" icon={Sparkles} title="One click">
          Tick, click, done. No confirmation for every file, and a summary of anything that couldn't go.
        </Card>
        <Card className="md:col-span-2" icon={Copy} title="Real duplicates" visual={<Dupes />} delay={0.08}>
          Byte-for-byte matches only. Shared-storage APFS copies don't inflate the total.
        </Card>
        <Card className="md:col-span-2" icon={Box} title="Docker and OrbStack" href="/docs/docker" linkText="Docker clean-up" delay={0.16}
          visual={
            <pre className="rounded-xl border border-fd-border bg-fd-background p-4 font-mono text-[14px] leading-7 text-fd-muted-foreground">
              <span className="text-fd-foreground">$ docker builder prune</span>{'\n'}
              <span className="text-safe">✓</span> 889 MB build cache{'\n'}
              <span className="text-safe">✓</span> 3 unused images
            </pre>
          }
        >
          Removed with Docker's own commands, never by touching its disk image.
        </Card>
        <Card className="md:col-span-3" icon={Lock} title="Hard limits, however it's spelled"
          visual={
            <div className="flex flex-wrap gap-2">
              {['/System', '~/Documents', '/Users/you', '/tmp/../etc'].map((p) => (
                <code key={p} className="rounded-lg border border-fd-border px-2.5 py-1.5 font-mono text-[14px] text-fd-muted-foreground">
                  <span className="text-[#e5484d]">✕ </span>{p}
                </code>
              ))}
            </div>
          }
        >
          System folders, your home folder and folders like Documents are never deleted as a whole, through symlinks or .. tricks.
        </Card>
        <Card className="md:col-span-3" icon={EyeOff} title="Private by design" href={repoUrl} linkText="Read the source" delay={0.08}>
          No account, no analytics, no network access. Your file list stays on your Mac, and the source is on GitHub for anyone to read.
        </Card>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ Tour */

const shots = [
  { id: 'map', label: 'Disk Map', icon: BarChart3, light: 'disk-map.png', dark: 'dark-disk-map.png', caption: 'Every folder by size, with its share of its parent.', width: 'max-w-5xl' },
  { id: 'menu', label: 'Menu bar', icon: Laptop, light: 'menu-bar.png', dark: 'dark-menu-bar.png', caption: 'Free space at a glance, and clean-up one click away.', width: 'max-w-sm' },
  { id: 'auto', label: 'Automation', icon: Clock, light: 'settings-automation.png', dark: 'dark-settings-automation.png', caption: 'Scheduled scans, auto-clean and low-space alerts.', width: 'max-w-xl' },
  { id: 'look', label: 'Appearance', icon: Palette, light: 'settings-appearance.png', dark: 'dark-settings-appearance.png', caption: 'Indigo by default. Any colour you like.', width: 'max-w-xl' },
];

export function Tour() {
  const [active, setActive] = useState(0);
  const reduce = useReducedMotion();
  const touched = useRef(false);
  useEffect(() => {
    if (reduce) return;
    const timer = setInterval(() => !touched.current && setActive((a) => (a + 1) % shots.length), 6000);
    return () => clearInterval(timer);
  }, [reduce]);

  return (
    <section className="border-y border-fd-border bg-fd-card/40 py-24 md:py-36">
      <div className="mx-auto max-w-6xl px-6 text-center">
        <Reveal className="mx-auto mb-12 max-w-3xl">
          <Kicker>Tour</Kicker>
          <h2 className="display text-[clamp(3rem,6.4vw,5.5rem)]">A native Mac app.</h2>
          <p className="mx-auto mt-6 max-w-xl text-lg text-fd-muted-foreground">SwiftUI, light and dark, your own accent colour. Not a web page in a box.</p>
        </Reveal>
        <Reveal>
          <div role="tablist" aria-label="Screens" className="glass mb-12 inline-flex flex-wrap justify-center gap-1 rounded-full p-1">
            {shots.map((s, i) => (
              <button
                key={s.id}
                role="tab"
                aria-selected={active === i}
                onClick={() => { touched.current = true; setActive(i); }}
                className={cn('font-display relative inline-flex h-10 items-center gap-2 rounded-full px-4 text-[17px] font-medium transition-colors', active === i ? 'text-fd-background' : 'text-fd-muted-foreground hover:text-fd-foreground')}
              >
                {active === i && <motion.span layoutId="tour-pill" className="glass-tint absolute inset-0 rounded-full" transition={{ type: 'spring', bounce: 0.2, duration: 0.55 }} />}
                <s.icon className="relative size-4" />
                <span className="relative">{s.label}</span>
              </button>
            ))}
          </div>
          <div className="grid">
            {shots.map((s, i) => (
              <motion.figure
                key={s.id}
                role="tabpanel"
                className={cn('[grid-area:1/1] mx-auto w-full', s.width)}
                initial={false}
                animate={{ opacity: active === i ? 1 : 0, y: active === i ? 0 : 12, scale: active === i ? 1 : 0.99 }}
                transition={{ duration: 0.7, ease }}
                style={{ pointerEvents: active === i ? 'auto' : 'none' }}
                aria-hidden={active !== i}
              >
                <img src={asset(`/screenshots/${s.light}`)} alt={`${appName}: ${s.label}`} className="shot block dark:hidden" loading={i === 0 ? 'eager' : 'lazy'} />
                <img src={asset(`/screenshots/${s.dark}`)} alt={`${appName}: ${s.label}`} className="shot hidden dark:block" loading={i === 0 ? 'eager' : 'lazy'} />
                <figcaption className="mt-7 text-[18px] text-fd-muted-foreground">{s.caption}</figcaption>
              </motion.figure>
            ))}
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ FAQ, CTA, footer */


export function Faq() {
  return (
    <section className="mx-auto grid max-w-6xl gap-12 px-6 py-24 md:grid-cols-[0.9fr_1.1fr] md:gap-20 md:py-36">
      <Reveal>
        <Kicker>Questions</Kicker>
        <h2 className="display text-[clamp(3rem,6.4vw,5.5rem)]">Good to know.</h2>
        <p className="mt-6 text-lg text-fd-muted-foreground">
          More in the{' '}
          <Link href="/docs/faq" className="text-fd-foreground underline underline-offset-4">
            FAQ
          </Link>
          .
        </p>
      </Reveal>
      <Reveal delay={0.1}>
        {faqs.map((f) => (
          <details key={f.q} className="group border-b border-fd-border">
            <summary className="font-display flex cursor-pointer list-none items-center justify-between gap-6 py-6 text-[22px] leading-tight font-medium [&::-webkit-details-marker]:hidden">
              {f.q}
              <span className="glass-btn grid size-9 flex-none place-items-center rounded-full text-fd-muted-foreground transition-transform duration-300 group-open:rotate-45">
                <Plus className="size-4" strokeWidth={2} />
              </span>
            </summary>
            <p className="pb-6 text-[19px] leading-relaxed text-fd-muted-foreground">{f.a}</p>
          </details>
        ))}
      </Reveal>
    </section>
  );
}

export function Cta() {
  return (
    <section className="relative isolate overflow-hidden border-t border-fd-border px-6 py-32 text-center md:py-44">
      <div className="toplight absolute -bottom-[560px] left-1/2 -z-10 h-[1000px] w-[1400px] -translate-x-1/2" />
      <Reveal>
        <motion.div className="mx-auto mb-10 w-fit" animate={{ rotate: [0, -6, 0] }} transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut' }}>
          <LogoMark className="size-20" />
        </motion.div>
        <h2 className="display text-[clamp(3.5rem,9.5vw,8.5rem)]">Your disk, back.</h2>
        <p className="mx-auto mt-6 max-w-lg text-lg text-fd-muted-foreground">One download, one scan, and you'll see what your Mac has been hoarding.</p>
        <div className="mt-10 flex flex-wrap justify-center gap-3">
          <a href={downloadUrl} className="glass-tint inline-flex h-12 items-center gap-2 rounded-full px-6 font-display text-lg font-semibold">
            <Download className="size-4" />
            Download for Mac
          </a>
          <a href={repoUrl} className="glass-btn inline-flex h-12 items-center gap-2 rounded-full px-6 font-display text-lg font-semibold">
            <GitHubIcon className="size-4" />
            Star on GitHub
          </a>
        </div>
      </Reveal>
    </section>
  );
}

export function Footer() {
  const cols = [
    { title: 'Product', links: [['Download', downloadUrl], ['Install', '/docs/install'], ['Release notes', releasesUrl]] },
    { title: 'Docs', links: [['Scan and clean', '/docs/guide'], ['What it finds', '/docs/what-it-finds'], ['FAQ', '/docs/faq']] },
    { title: 'Project', links: [['Source code', repoUrl], ['Report a problem', `${repoUrl}/issues`], ['License', `${repoUrl}/blob/main/LICENSE`]] },
  ];
  return (
    <footer className="relative overflow-hidden border-t border-fd-border">
      <div className="mx-auto grid max-w-6xl gap-14 px-6 pt-20 pb-12 md:grid-cols-[1.3fr_2fr]">
        <div>
          <Link href="/" className="inline-flex items-center gap-3">
            <span className="grid size-12 place-items-center rounded-[14px] bg-[#17171c] ring-1 ring-white/10">
              <LogoMark className="size-7 text-white" />
            </span>
            <span className="font-display text-[34px] leading-none font-semibold">{appName}</span>
          </Link>
          <p className="mt-5 max-w-xs text-[18px] leading-relaxed text-fd-muted-foreground">
            Free, open-source Mac storage cleaner for developers. MIT licensed.
          </p>
          <a href={downloadUrl} className="glass-tint font-display mt-7 inline-flex h-11 items-center gap-2 rounded-full px-5 text-lg font-semibold">
            <Download className="size-4" />
            Download for Mac
          </a>
        </div>
        <div className="grid grid-cols-2 gap-10 sm:grid-cols-3">
          {cols.map((c) => (
            <div key={c.title}>
              <p className="font-display mb-4 text-[19px] font-semibold">{c.title}</p>
              {c.links.map(([label, href]) => (
                <Link key={label} href={href} className="block py-1.5 text-[18px] text-fd-muted-foreground transition-colors hover:text-fd-foreground">
                  {label}
                </Link>
              ))}
            </div>
          ))}
        </div>
      </div>
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 border-t border-fd-border px-6 py-6 text-sm text-fd-muted-foreground">
        <span>© {new Date().getFullYear()} {author}</span>
        <span>Made for developers who keep running out of disk.</span>
      </div>
      <div className="pointer-events-none mx-auto flex max-w-6xl items-end gap-[3vw] px-6 select-none" aria-hidden="true">
        <LogoMark className="mb-[2.2vw] size-[13vw] max-h-48 max-w-48 flex-none text-fd-foreground/[0.07]" sliceClassName="opacity-60" />
        <p className="font-display translate-y-[22%] text-[clamp(6rem,22vw,19rem)] leading-[0.8] font-bold tracking-tight text-fd-foreground/[0.07] uppercase">
          {appName}
        </p>
      </div>
    </footer>
  );
}
