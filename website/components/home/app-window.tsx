'use client';
import { useEffect, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import { asset } from '@/lib/shared';
import { cn } from '@/lib/cn';

/**
 * A replica of Reclaim's window that plays one clean-up the way the app does it: a scan on the Overview with
 * the scan card, Safe items ticked when it finishes, Build Caches opened from the sidebar, Delete, freed.
 * Example data only; follows the page's light or dark theme like the app does.
 */

const rows = [
  { name: 'DerivedData/Storefront-ghxqv', where: '~/Library/Developer/Xcode', size: 6.89, when: '3 Nov, 2026' },
  { name: '.next', where: '~/Projects/storefront', size: 2.14, when: '11 Nov, 2026' },
  { name: 'target', where: '~/Projects/engine', size: 1.92, when: '28 Oct, 2026' },
  { name: '.turbo', where: '~/Projects/monorepo', size: 0.64, when: '9 Nov, 2026' },
  { name: 'build/intermediates', where: '~/Projects/android/app', size: 0.41, when: '30 Oct, 2026' },
  { name: '__pycache__', where: '~/Projects/ml-tools', size: 0.096, when: '12 Nov, 2026' },
];
const total = rows.reduce((s, r) => s + r.size, 0);
// Like ByteCountFormatter: two decimals for GB, one for MB, none when it is .0.
const fmt = (gb: number) => (gb >= 1 ? `${+gb.toFixed(2)} GB` : `${+(gb * 1000).toFixed(1)} MB`);

// The app's own SF Symbols (SuggestionCategory.systemImage and the sidebar), rendered by brand/sf-symbols.swift
// into masks so they take the text colour.
function Symbol({ name, className }: { name: string; className?: string }) {
  const url = `url(${asset(`/sf-symbols/${name.replaceAll('.', '-')}.png`)})`;
  return (
    <span
      aria-hidden="true"
      className={cn('inline-block flex-none bg-current', className)}
      style={{ maskImage: url, WebkitMaskImage: url, maskSize: 'contain', WebkitMaskSize: 'contain', maskRepeat: 'no-repeat', WebkitMaskRepeat: 'no-repeat', maskPosition: 'center', WebkitMaskPosition: 'center' }}
    />
  );
}

const sidebar = [
  { icon: 'shippingbox', label: 'Dependencies', size: '17.31 GB' },
  { icon: 'hammer', label: 'Build Caches', size: '12.1 GB', target: true },
  { icon: 'archivebox', label: 'Package Caches', size: '3.62 GB' },
  { icon: 'iphone', label: 'Mobile Tooling', size: '2.88 GB' },
  { icon: 'square.stack.3d.up', label: 'App Caches', size: '1.19 GB' },
  { icon: 'gearshape.2', label: 'System Junk', size: '97.2 MB' },
  { icon: 'app.dashed', label: 'App Leftovers', size: '25 KB' },
  { icon: 'doc.text', label: 'Logs', size: '12 KB' },
];
const explore = [
  { icon: 'chart.bar.doc.horizontal', label: 'Disk Map' },
  { icon: 'doc.richtext', label: 'Large Files', size: '21.84 GB' },
  { icon: 'doc.on.doc', label: 'Duplicates', size: '774.3 MB' },
  { icon: 'shippingbox.circle', label: 'Containers', size: '1.42 GB' },
  { icon: 'lock.shield', label: 'System' },
];

type Phase = 'idle' | 'scan' | 'scanned' | 'list' | 'delete' | 'done';

const topCategories = [
  { icon: 'shippingbox', label: 'Dependencies', items: 41, size: '17.31 GB' },
  { icon: 'hammer', label: 'Build Caches', items: 6, size: '12.1 GB' },
  { icon: 'archivebox', label: 'Package Caches', items: 3, size: '3.62 GB' },
  { icon: 'iphone', label: 'Mobile Tooling', items: 2, size: '2.88 GB' },
];
const scanPaths = [
  '/Users/you/Library/Developer/Xcode/DerivedData/Storefront-ghxqv/Build',
  '/Users/you/Projects/storefront/node_modules/next/dist/compiled',
  '/Users/you/.gradle/caches/modules-2/files-2.1/org.jetbrains.kotlin',
  '/Users/you/Projects/engine/target/debug/deps',
  '/Applications/Xcode.app/Contents/Developer/Platforms',
  '/Users/you/Library/Caches/com.spotify.client/Data',
];
const disk = { total: 245.11, used: 186.85 };

function Folder() {
  return (
    <svg viewBox="0 0 22 18" className="h-[17px] w-[21px] flex-none" aria-hidden="true">
      <path d="M1 3.2C1 2 2 1 3.2 1h5l2 2.2h8.6C20 3.2 21 4.2 21 5.4v9.4c0 1.2-1 2.2-2.2 2.2H3.2C2 17 1 16 1 14.8z" fill="#3d97ef" />
      <path d="M1 6h20v8.8c0 1.2-1 2.2-2.2 2.2H3.2C2 17 1 16 1 14.8z" fill="#66b3f6" />
    </svg>
  );
}

export function AppWindow() {
  const reduce = useReducedMotion();
  const [phase, setPhase] = useState<Phase>(reduce ? 'scanned' : 'idle');
  const [progress, setProgress] = useState(reduce ? 1 : 0);
  const [gone, setGone] = useState(0);
  const [cursor, setCursor] = useState({ x: 0, y: 0, visible: false, down: false });
  const root = useRef<HTMLDivElement>(null);
  const buildRef = useRef<HTMLDivElement>(null);
  const deleteRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (reduce) return;
    let cancelled = false;
    const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
    // Layout position inside the window, unaffected by its 3D tilt.
    const pointAt = (el: HTMLElement | null) => {
      let x = 0, y = 0;
      for (let n: HTMLElement | null = el; n && n !== root.current; n = n.offsetParent as HTMLElement | null) {
        x += n.offsetLeft;
        y += n.offsetTop;
      }
      return { x: x + (el?.offsetWidth ?? 0) * 0.55, y: y + (el?.offsetHeight ?? 0) * 0.55 };
    };
    const rest = () => ({ x: (root.current?.offsetWidth ?? 900) - 160, y: (root.current?.offsetHeight ?? 600) - 170 });
    const click = async () => {
      setCursor((c) => ({ ...c, down: true }));
      await sleep(150);
      setCursor((c) => ({ ...c, down: false }));
    };

    (async () => {
      await sleep(1100);
      while (!cancelled) {
        setPhase('scan'); setGone(0); setProgress(0);
        setCursor({ ...rest(), visible: false, down: false });
        // The scan, on the Overview.
        const t0 = performance.now();
        await new Promise<void>((done) => {
          const tick = () => {
            const t = Math.min(1, (performance.now() - t0) / 4200);
            setProgress(t);
            t < 1 && !cancelled ? requestAnimationFrame(tick) : done();
          };
          requestAnimationFrame(tick);
        });
        setPhase('scanned');
        await sleep(2400);

        // Open Build Caches from the sidebar; its Safe items are already ticked.
        setCursor({ ...pointAt(buildRef.current), visible: true, down: false });
        await sleep(1050);
        await click();
        setPhase('list');
        await sleep(1300);

        // Delete.
        setCursor((c) => ({ ...c, ...pointAt(deleteRef.current) }));
        await sleep(1050);
        await click();
        setPhase('delete');
        for (let i = 1; i <= rows.length && !cancelled; i++) { await sleep(85); setGone(i); }
        await sleep(350);
        setPhase('done');
        setCursor((c) => ({ ...c, ...rest() }));
        await sleep(4000);
        setCursor((c) => ({ ...c, visible: false }));
        await sleep(500);
      }
    })();
    return () => { cancelled = true; };
  }, [reduce]);

  const onOverview = phase === 'idle' || phase === 'scan' || phase === 'scanned';
  const scanned = !(phase === 'idle' || phase === 'scan');
  const cleared = phase === 'done';
  const ticked = scanned && phase !== 'delete' && !cleared;
  // Scan counters, eased like a real scan that slows down at the end.
  const eased = 1 - Math.pow(1 - progress, 2.2);
  const files = Math.round(2717258 * eased);
  const folders = Math.round(411419 * eased);
  const read = 145.48 * eased;
  const path = scanPaths[Math.min(scanPaths.length - 1, Math.floor(progress * scanPaths.length))];

  return (
    <div
      ref={root}
      role="img"
      aria-label="Reclaim scanning a Mac from its Overview, then opening Build Caches and deleting six caches to free 12.1 GB."
      className={cn(
        'relative grid h-[620px] w-full grid-cols-1 overflow-hidden rounded-[16px] text-left text-[13px] leading-snug',
        'bg-white text-[#1d1d1f] ring-1 ring-black/10 shadow-[0_0_0_0.5px_rgb(0_0_0/0.08),0_40px_100px_-30px_rgb(0_0_0/0.35)] md:grid-cols-[230px_1fr]',
        'dark:bg-[#201f1e] dark:text-[#f5f5f7] dark:ring-white/12 dark:shadow-[0_0_0_1px_rgb(0_0_0/0.8),0_60px_140px_-30px_rgb(0_0_0/0.95)]',
      )}
      style={{ fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", var(--font-inter), sans-serif' }}
    >
      {/* Sidebar */}
      <aside className="relative hidden border-r border-black/[0.08] bg-[#ededec] px-2.5 pt-[56px] pb-3 md:block dark:border-black/50 dark:bg-[#292624]">
        <Lights className="absolute top-[20px] left-[19px]" />
        <span className={cn(roundButton, 'absolute top-2 right-2.5 size-9')}>
          <Symbol name="sidebar.left" className="size-[19px]" />
        </span>
        <SideItem icon="internaldrive" label="Overview" active={onOverview} />
        <p className="mx-2 mt-3 mb-1 text-[11px] font-semibold text-[#8e8e93] dark:text-[#7c7a78]">Suggestions</p>
        {scanned ? (
          sidebar.map((s, i) => (
            <motion.div key={s.label} ref={s.target ? buildRef : undefined} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.04 }}>
              <SideItem
                icon={s.icon}
                label={s.label}
                size={s.target && (phase === 'delete' || cleared) ? undefined : s.size}
                active={s.target && !onOverview}
              />
            </motion.div>
          ))
        ) : (
          <p className="px-2 py-1.5 text-[13px] text-[#8e8e93] dark:text-[#8a8886]">{phase === 'scan' ? 'Scanning…' : 'Scan to see suggestions'}</p>
        )}
        <p className="mx-2 mt-3 mb-1 text-[11px] font-semibold text-[#8e8e93] dark:text-[#7c7a78]">Explore</p>
        {explore.map((s) => (
          <SideItem key={s.label} icon={s.icon} label={s.label} size={scanned ? s.size : undefined} />
        ))}
      </aside>

      {/* Main */}
      <section className="relative grid min-h-0 min-w-0 grid-rows-[56px_minmax(0,1fr)] overflow-hidden pb-12 bg-white dark:bg-[#201f1e]">
        {onOverview ? (
          <>
            <div className="flex items-center gap-2 px-3 md:pl-5">
              <Lights className="mr-1 md:hidden" />
              <p className="text-[15px] font-semibold text-[#3a3a3c] dark:text-[#d8d6d4]">Overview</p>
            </div>
            <Overview phase={phase} progress={progress} files={files} folders={folders} read={read} path={path} />
          </>
        ) : (
          <ListScreen gone={gone} ticked={ticked} cleared={cleared} />
        )}

        {/* The action bar shows whenever something is ticked, as in the app. */}
        <div className={cn('absolute inset-x-0 bottom-0 z-[1] flex h-12 items-center justify-end gap-3 border-t border-black/[0.08] bg-white px-4 transition-opacity duration-300 md:justify-between md:pl-4 dark:border-white/[0.07] dark:bg-[#201f1e]', !scanned && 'opacity-0')}>
          <span className="hidden text-[12px] text-[#86868b] md:block dark:text-[#8a8886]">Ticked items are deleted permanently.</span>
          <span className="flex items-center gap-2">
            <span className="inline-flex h-[26px] items-center rounded-[7px] bg-brand/[0.07] px-3 text-[13px] text-brand dark:bg-brand/20 dark:text-[#a5a4f6]">Untick All</span>
            <span
              ref={deleteRef}
              className={cn(
                'inline-flex h-[26px] min-w-[176px] items-center justify-center rounded-[7px] bg-[#f9272d] px-3 text-[13px] whitespace-nowrap text-white tabular-nums transition-all duration-200',
                ticked ? 'opacity-100' : 'opacity-40',
                cursor.down && phase === 'list' && 'scale-95',
              )}
            >
              {ticked ? `Delete ${rows.length} items · ${fmt(total)}` : 'Delete 0 items'}
            </span>
          </span>
        </div>

        {/* Toast */}
        <motion.div
          initial={false}
          animate={{ opacity: cleared ? 1 : 0, y: cleared ? 0 : 14, scale: cleared ? 1 : 0.98 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          className="glass absolute right-5 bottom-[72px] flex items-center gap-3 rounded-2xl py-3 pr-5 pl-3"
        >
          <span className="grid size-[30px] place-items-center rounded-[9px] bg-safe/15 text-safe">
            <Symbol name="checkmark.circle" className="size-5" />
          </span>
          <span>
            <span className="block text-[14px] font-semibold">Freed {fmt(total)}</span>
            <span className="block text-[11.5px] text-[#86868b] dark:text-[#98989d]">6 items deleted · no confirmation needed</span>
          </span>
        </motion.div>
      </section>

      {/* macOS's own arrow pointer (NSCursor.arrow, exported by brand/cursor.swift); its hot spot is at (5, 5). */}
      <motion.img
        src={asset('/cursor-arrow.png')}
        alt=""
        width={28}
        height={40}
        className="pointer-events-none absolute top-0 left-0 z-10 h-10 w-7 max-w-none select-none"
        initial={false}
        animate={{ x: cursor.x - 5, y: cursor.y - 5, opacity: cursor.visible ? 1 : 0, scale: cursor.down ? 0.88 : 1 }}
        style={{ transformOrigin: '5px 5px' }}
        transition={{ x: { duration: 1, ease: [0.16, 1, 0.3, 1] }, y: { duration: 1, ease: [0.16, 1, 0.3, 1] }, opacity: { duration: 0.3 }, scale: { duration: 0.12 } }}
        aria-hidden="true"
      />
    </div>
  );
}

/** The Overview: storage bar, the scan card, and the top categories once a scan has finished. */
function Overview({ phase, progress, files, folders, read, path }: {
  phase: Phase; progress: number; files: number; folders: number; read: number; path: string;
}) {
  const scanning = phase === 'scan' || phase === 'idle';
  const reclaimable = scanning ? 0 : 37.2;
  const pct = (v: number) => `${(v / disk.total) * 100}%`;
  const secondary = 'text-[#86868b] dark:text-[#8a8886]';
  return (
    <div className="min-h-0 overflow-hidden px-5 pt-3 md:px-6">
      <div className="flex items-baseline justify-between">
        <p className="text-[17px] font-semibold">Macintosh HD</p>
        <p className={cn('text-[13px] tabular-nums', secondary)}>{fmt(disk.total - disk.used)} free of {fmt(disk.total)}</p>
      </div>
      <div className="mt-2.5 flex h-3.5 overflow-hidden rounded-full bg-black/[0.07] dark:bg-white/[0.1]">
        <div className="bg-[#8a8a8e] transition-[width] duration-700" style={{ width: pct(disk.used - reclaimable) }} />
        <div className="bg-brand transition-[width] duration-700" style={{ width: pct(reclaimable) }} />
      </div>
      <div className={cn('mt-2 flex flex-wrap gap-x-5 gap-y-1 text-[12px]', secondary)}>
        <span className="flex items-center gap-1.5"><i className="size-2.5 rounded-[3px] bg-[#8a8a8e]" />Used <b className="font-medium text-[#1d1d1f] tabular-nums dark:text-[#f5f5f7]">{fmt(disk.used - reclaimable)}</b></span>
        <span className="flex items-center gap-1.5"><i className="size-2.5 rounded-[3px] bg-brand" />Reclaimable <b className="font-medium text-[#1d1d1f] tabular-nums dark:text-[#f5f5f7]">{reclaimable ? fmt(reclaimable) : 'Zero KB'}</b></span>
        <span className="flex items-center gap-1.5"><i className="size-2.5 rounded-[3px] bg-black/[0.1] dark:bg-white/[0.15]" />Free <b className="font-medium text-[#1d1d1f] tabular-nums dark:text-[#f5f5f7]">{fmt(disk.total - disk.used)}</b></span>
      </div>

      {/* The scan card, as in the app. */}
      <div className="mt-5 flex items-center gap-4 rounded-2xl border border-black/[0.07] bg-[#f6f6f6] p-4 dark:border-white/[0.08] dark:bg-white/[0.05]">
        <span className="grid size-[52px] flex-none place-items-center rounded-full bg-brand/[0.14]">
          {scanning ? <Spinner /> : <Symbol name="checkmark" className="size-6 text-brand dark:text-[#8f8df5]" />}
        </span>
        <div className="min-w-0 flex-1">
          {scanning ? (
            <>
              <div className="flex items-baseline justify-between gap-3">
                <p className="text-[15px] font-semibold">Scanning…</p>
                <p className={cn('text-[12px] tabular-nums', secondary)}>about {Math.min(99, Math.round(progress * 100))}%</p>
              </div>
              <div className="mt-2 h-2 overflow-hidden rounded-full bg-black/[0.08] dark:bg-white/[0.12]">
                <div className="h-full rounded-full bg-brand" style={{ width: `${progress * 100}%` }} />
              </div>
              <div className="mt-2.5 flex gap-5">
                <Metric value={files.toLocaleString('en-US')} label="files" />
                <Metric value={fmt(read)} label="read" />
                <Metric value={folders.toLocaleString('en-US')} label="folders" />
              </div>
              <p className="mt-1.5 truncate text-[11px] text-[#aeaeb2] dark:text-[#6e6c6a]">{path}</p>
            </>
          ) : (
            <>
              <p className="text-[15px] font-semibold">Last scan <span className={cn('ml-1 text-[12px] font-normal', secondary)}>just now</span></p>
              <div className="mt-2 flex flex-wrap gap-x-6 gap-y-2">
                <Metric value={fmt(37.2)} label="reclaimable" prominent />
                <Metric value={fmt(13.4)} label="Safe to delete" safe />
                <Metric value={(2717258).toLocaleString('en-US')} label="files scanned" />
                <Metric value="36 s" label="scan time" />
              </div>
            </>
          )}
        </div>
        <span className={cn('hidden flex-none items-center justify-center gap-1.5 rounded-full px-4 text-[13px] font-medium sm:inline-flex', 'h-8',
          scanning ? 'bg-black/[0.06] text-brand dark:bg-white/[0.1] dark:text-[#a5a4f6]' : 'bg-brand text-white')}>
          {scanning ? 'Stop' : <><Symbol name="arrow.clockwise" className="size-3.5" />Scan Again</>}
        </span>
      </div>

      {/* Top categories, after a scan. */}
      <motion.div initial={false} animate={{ opacity: scanning ? 0 : 1, y: scanning ? 8 : 0 }} transition={{ duration: 0.5 }} className="mt-5">
        <p className="mb-2 text-[13px] font-semibold">Top categories</p>
        <div className="overflow-hidden rounded-xl bg-[#f6f6f6] dark:bg-white/[0.05]">
          {topCategories.map((c, i) => (
            <div key={c.label} className={cn('flex h-9 items-center gap-2.5 px-3', i > 0 && 'border-t border-black/[0.06] dark:border-white/[0.06]')}>
              <Symbol name={c.icon} className="size-[18px] text-brand dark:text-[#8f8df5]" />
              <span className="flex-1">{c.label}</span>
              <span className={cn('text-[12px]', secondary)}>{c.items} items</span>
              <span className="w-20 text-right tabular-nums">{c.size}</span>
              <Symbol name="chevron.right" className="size-3 text-[#c7c7cc] dark:text-[#5a5a60]" />
            </div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}

/** Build Caches, with its Safe items ticked, then deleted. */
function ListScreen({ gone, ticked, cleared }: { gone: number; ticked: boolean; cleared: boolean }) {
  const cols = 'grid-cols-[34px_minmax(0,1fr)_92px] sm:grid-cols-[34px_minmax(0,1fr)_100px_96px] lg:grid-cols-[34px_minmax(0,1fr)_104px_96px_108px]';
  return (
    <>
      <div className="relative flex items-center gap-2 px-3 md:pl-5">
        <Lights className="mr-1 md:hidden" />
        <div className="min-w-0">
          <p className="text-[13px] font-bold">Build Caches</p>
          <p className="text-[11px] text-[#86868b] tabular-nums dark:text-[#98989d]">{gone >= rows.length ? 'No items' : `${rows.length} items · ${fmt(total)}`}</p>
        </div>
        <span className="flex-1" />
        <span className={capsule}>Select All Safe</span>
        <span className={cn(capsule, 'hidden lg:inline-flex')}>Deselect All</span>
        <span className={cn(roundButton, 'hidden size-9 lg:grid')}>
          <Symbol name="sidebar.right" className="size-[19px]" />
        </span>
        <span className={cn(capsule, 'hidden w-52 justify-start gap-2 font-normal text-[#8e8e93] lg:inline-flex dark:text-[#8a8886]')}>
          <Symbol name="magnifyingglass" className="size-4" /> Filter by name or path
        </span>
      </div>

      <div className="grid min-h-0 grid-rows-[32px_minmax(0,1fr)] overflow-hidden">
        <div className={cn('grid items-center border-b border-black/[0.08] px-3 text-[12px] text-[#3a3a3c] dark:border-white/[0.08] dark:text-[#c8c6c4]', cols)}>
          <span />
          <span className={colHead}>Name</span>
          <span className={cn(colHead, 'justify-between font-semibold')}>
            Size <Symbol name="chevron.down" className="mr-1 size-2.5 opacity-60" />
          </span>
          <span className={cn(colHead, 'hidden sm:flex')}>Safety</span>
          <span className={cn(colHead, 'hidden lg:flex')}>Modified</span>
        </div>

        <div className="relative min-h-0 overflow-hidden px-2.5 pt-1.5">
          {rows.map((r, i) => (
            <motion.div
              key={r.name}
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: i < gone ? 0 : 1, height: i < gone ? 0 : 40, x: i < gone ? -14 : 0, y: 0 }}
              transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1], delay: gone ? 0 : i * 0.03 }}
              className={cn('grid items-center overflow-hidden rounded-[10px] px-0.5', cols, i % 2 === 1 && 'bg-[#f2f3f3] dark:bg-white/[0.04]')}
            >
              <span className={cn('ml-2 grid size-[15px] place-items-center rounded-[4px] transition-colors duration-200', ticked ? 'bg-brand' : 'bg-[#e6e6e6] dark:bg-white/[0.14]')}>
                <Symbol name="checkmark" className={cn('size-3 text-white transition-opacity duration-200', ticked ? 'opacity-100' : 'opacity-0')} />
              </span>
              <span className="flex min-w-0 items-center gap-2.5 pl-2">
                <Folder />
                <span className="min-w-0">
                  <span className="block truncate">{r.name}</span>
                  <span className="block truncate text-[11px] text-[#86868b] dark:text-[#8a8886]">{r.where}</span>
                </span>
              </span>
              <span className="pr-4 text-right tabular-nums">{fmt(r.size)}</span>
              <span className="hidden sm:block">
                <span className="ml-1 inline-flex rounded-full bg-[#34c759]/[0.14] px-2 py-[3px] text-[11px] font-semibold text-[#28a745] dark:text-[#30d158]">Safe</span>
              </span>
              <span className="hidden pl-1 text-[13px] text-[#86868b] lg:block dark:text-[#8a8886]">{r.when}</span>
            </motion.div>
          ))}
          {Array.from({ length: 12 }, (_, k) => (
            <div key={k} aria-hidden="true" className={cn('h-10 rounded-[10px]', (rows.length + k) % 2 === 1 && 'bg-[#f2f3f3] dark:bg-white/[0.04]')} />
          ))}
          <div className={cn('pointer-events-none absolute inset-0 grid place-content-center justify-items-center gap-2 text-center transition-opacity duration-500', cleared ? 'opacity-100' : 'opacity-0')}>
            <Symbol name="checkmark.circle" className="size-11 text-[#c7c7cc] dark:text-[#5a5a60]" />
            <p className="text-[14px] font-semibold">Nothing to Show</p>
            <p className="text-[12px] text-[#86868b] dark:text-[#98989d]">Nothing here.</p>
          </div>
        </div>
      </div>
    </>
  );
}

/** A figure with a small label under it, as on the app's scan card. */
function Metric({ value, label, prominent, safe }: { value: string; label: string; prominent?: boolean; safe?: boolean }) {
  return (
    <span className="block">
      <span className={cn('block tabular-nums', prominent ? 'text-[19px] font-bold text-brand dark:text-[#8f8df5]' : 'text-[15px] font-semibold',
        safe && 'text-[#28a745] dark:text-[#30d158]')}>{value}</span>
      <span className="block text-[11px] text-[#86868b] dark:text-[#8a8886]">{label}</span>
    </span>
  );
}

/** macOS's indeterminate spinner: twelve spokes, fading round. */
function Spinner() {
  return (
    <motion.svg viewBox="0 0 24 24" className="size-6 text-[#6e6e73] dark:text-[#aeaeb2]" animate={{ rotate: 360 }}
      transition={{ duration: 1, repeat: Infinity, ease: (t) => Math.floor(t * 12) / 12 }} aria-hidden="true">
      {Array.from({ length: 12 }, (_, i) => (
        <line key={i} x1="12" y1="2.5" x2="12" y2="7" stroke="currentColor" strokeWidth="2" strokeLinecap="round"
          opacity={0.2 + (0.8 * i) / 11} transform={`rotate(${i * 30} 12 12)`} />
      ))}
    </motion.svg>
  );
}

// macOS 26 toolbar controls: white capsules with a hairline and a soft shadow.
const capsule =
  'inline-flex h-9 items-center justify-center whitespace-nowrap rounded-full bg-white px-3.5 text-[13px] font-medium ring-[0.5px] ring-black/[0.12] shadow-[0_1px_3px_rgb(0_0_0/0.08)] transition-all duration-150 dark:bg-white/[0.1] dark:ring-white/[0.12] dark:shadow-none';
const roundButton =
  'grid place-items-center rounded-full bg-white ring-[0.5px] ring-black/[0.12] shadow-[0_1px_3px_rgb(0_0_0/0.08)] dark:bg-white/[0.1] dark:ring-white/[0.12] dark:shadow-none';
const colHead = 'flex h-full items-center border-l border-black/[0.08] pl-2.5 dark:border-white/[0.08]';

function Lights({ className }: { className?: string }) {
  return (
    <span className={cn('flex gap-2', className)} aria-hidden="true">
      <i className="size-3 rounded-full bg-[#ff5f57] ring-[0.5px] ring-black/20" />
      <i className="size-3 rounded-full bg-[#febc2e] ring-[0.5px] ring-black/20" />
      <i className="size-3 rounded-full bg-[#28c840] ring-[0.5px] ring-black/20" />
    </span>
  );
}

function SideItem({ icon, label, size, active }: { icon: string; label: string; size?: string; active?: boolean }) {
  return (
    <div
      className={cn(
        'grid h-8 grid-cols-[22px_1fr_auto] items-center gap-2 rounded-[10px] px-2 text-[13px]',
        // The app's selection: the accent colour with white text and icon.
        active ? 'bg-brand font-semibold text-white' : 'text-[#1d1d1f] dark:text-[#ebe9e7]',
      )}
    >
      <Symbol name={icon} className={cn('-mx-[3px] size-[28px]', active ? 'text-white' : 'text-brand dark:text-[#8f8df5]')} />
      <span className="truncate">{label}</span>
      {size !== undefined && (
        <span className={cn('text-[11px] tabular-nums', active ? 'font-semibold text-white/85' : 'text-[#8e8e93] dark:text-[#8a8886]')}>{size}</span>
      )}
    </div>
  );
}
