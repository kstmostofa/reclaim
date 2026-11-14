'use client';
import { useEffect, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import {
  BarChart3,
  Box,
  CheckCircle2,
  Copy,
  HardDrive,
  Layers,
  Laptop,
  Package,
  Search,
  Settings2,
  Wrench,
} from 'lucide-react';
import { cn } from '@/lib/cn';

/**
 * A replica of Reclaim's window that plays one clean-up: scan, select the Safe items, delete, freed.
 * Example data only; follows the page's light or dark theme like the app does.
 */

const rows = [
  { name: 'DerivedData/Storefront-ghxqv', where: '~/Library/Developer/Xcode', size: 6.89, when: '3 Nov' },
  { name: '.next', where: '~/Projects/storefront', size: 2.14, when: '11 Nov' },
  { name: 'target', where: '~/Projects/engine', size: 1.92, when: '28 Oct' },
  { name: '.turbo', where: '~/Projects/monorepo', size: 0.64, when: '9 Nov' },
  { name: 'build/intermediates', where: '~/Projects/android/app', size: 0.41, when: '30 Oct' },
  { name: '__pycache__', where: '~/Projects/ml-tools', size: 0.096, when: '12 Nov' },
];
const total = rows.reduce((s, r) => s + r.size, 0);
const fmt = (gb: number) => (gb >= 1 ? `${gb.toFixed(2)} GB` : `${Math.round(gb * 1000)} MB`);

const sidebar = [
  { icon: Package, label: 'Dependencies', size: '17.3 GB' },
  { icon: Wrench, label: 'Build Caches', size: '12.1 GB', active: true },
  { icon: Layers, label: 'Package Caches', size: '3.6 GB' },
  { icon: Laptop, label: 'Mobile Tooling', size: '2.9 GB' },
  { icon: Box, label: 'App Caches', size: '1.2 GB' },
  { icon: Settings2, label: 'System Junk', size: '94 MB' },
];
const explore = [
  { icon: BarChart3, label: 'Disk Map' },
  { icon: Copy, label: 'Duplicates', size: '774 MB' },
  { icon: Package, label: 'Containers', size: '1.4 GB' },
];

type Phase = 'idle' | 'scan' | 'found' | 'select' | 'delete' | 'done';

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
  const [phase, setPhase] = useState<Phase>(reduce ? 'select' : 'idle');
  const [shown, setShown] = useState(reduce ? rows.length : 0);
  const [ticked, setTicked] = useState(reduce ? rows.length : 0);
  const [gone, setGone] = useState(0);
  const [files, setFiles] = useState(0);
  const [progress, setProgress] = useState(0);
  const [cursor, setCursor] = useState({ x: 0, y: 0, visible: false, down: false });
  const root = useRef<HTMLDivElement>(null);
  const selectRef = useRef<HTMLSpanElement>(null);
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
      return { x: x + (el?.offsetWidth ?? 0) * 0.6, y: y + (el?.offsetHeight ?? 0) * 0.55 };
    };
    const rest = () => ({ x: (root.current?.offsetWidth ?? 900) - 140, y: (root.current?.offsetHeight ?? 600) - 150 });
    const click = async () => {
      setCursor((c) => ({ ...c, down: true }));
      await sleep(150);
      setCursor((c) => ({ ...c, down: false }));
    };

    (async () => {
      await sleep(1300);
      while (!cancelled) {
        setPhase('scan'); setShown(0); setTicked(0); setGone(0); setFiles(0); setProgress(0);
        setCursor({ ...rest(), visible: false, down: false });
        const t0 = performance.now();
        const scanMs = 3400;
        const tick = () => {
          const t = Math.min(1, (performance.now() - t0) / scanMs);
          setProgress(t);
          setFiles(Math.round(2717258 * (1 - Math.pow(1 - t, 3))));
          if (t < 1 && !cancelled) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
        for (let i = 1; i <= rows.length && !cancelled; i++) { await sleep(520); setShown(i); }
        await sleep(600);
        setPhase('found');
        await sleep(700);

        setCursor({ ...pointAt(selectRef.current), visible: true, down: false });
        await sleep(1050);
        await click();
        setPhase('select');
        for (let i = 1; i <= rows.length && !cancelled; i++) { await sleep(110); setTicked(i); }
        await sleep(800);

        setCursor((c) => ({ ...c, ...pointAt(deleteRef.current) }));
        await sleep(1050);
        await click();
        setPhase('delete');
        for (let i = 1; i <= rows.length && !cancelled; i++) { await sleep(85); setGone(i); }
        await sleep(350);
        setPhase('done');
        setCursor((c) => ({ ...c, ...rest() }));
        await sleep(4200);
        setCursor((c) => ({ ...c, visible: false }));
        await sleep(500);
      }
    })();
    return () => { cancelled = true; };
  }, [reduce]);

  const tickedSize = rows.slice(0, ticked).reduce((s, r) => s + r.size, 0);
  const scanning = phase === 'scan';
  const cleared = phase === 'done';
  const sidebarSize = (size: string, i: number) => (phase === 'idle' || (scanning && progress < 0.15 + i * 0.12) ? '—' : size);

  return (
    <div
      ref={root}
      role="img"
      aria-label="Reclaim scanning a Mac, ticking six build caches and deleting them to free 12.1 GB."
      className={cn(
        'relative grid h-[620px] w-full grid-cols-1 overflow-hidden rounded-[14px] text-left text-[13px] leading-snug md:grid-cols-[228px_1fr]',
        'bg-white text-[#1d1d1f] ring-1 ring-black/10 shadow-[0_0_0_0.5px_rgb(0_0_0/0.08),0_40px_100px_-30px_rgb(0_0_0/0.35)]',
        'dark:bg-[#1e1e20] dark:text-[#f5f5f7] dark:ring-white/12 dark:shadow-[0_0_0_1px_rgb(0_0_0/0.8),0_60px_140px_-30px_rgb(0_0_0/0.95)]',
      )}
      style={{ fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", var(--font-inter), sans-serif' }}
    >
      {/* Sidebar */}
      <aside className="relative hidden border-r border-black/[0.06] bg-[#f4f4f6] px-2.5 pt-[52px] pb-3 md:block dark:border-black/50 dark:bg-[#2a2a2d]">
        <Lights className="absolute top-[18px] left-4" />
        <SideItem icon={HardDrive} label="Overview" />
        <p className="mx-2.5 mt-3.5 mb-1.5 text-[11px] font-semibold text-[#86868b] dark:text-[#98989d]">Suggestions</p>
        {sidebar.map((s, i) => (
          <SideItem
            key={s.label}
            icon={s.icon}
            label={s.label}
            size={s.active && (phase === 'delete' || cleared) ? '—' : sidebarSize(s.size, i)}
            active={s.active}
          />
        ))}
        <p className="mx-2.5 mt-3.5 mb-1.5 text-[11px] font-semibold text-[#86868b] dark:text-[#98989d]">Explore</p>
        {explore.map((s, i) => (
          <SideItem key={s.label} icon={s.icon} label={s.label} size={s.size ? sidebarSize(s.size, i + 3) : undefined} />
        ))}
      </aside>

      {/* Main */}
      <section className="relative grid min-w-0 grid-rows-[56px_30px_1fr_54px] bg-white dark:bg-[#1e1e20]">
        <div className="relative flex items-center gap-3 border-b border-black/[0.07] px-4 md:pl-5 dark:border-black/60 dark:bg-[#232326]">
          <Lights className="mr-1 md:hidden" />
          <div className="min-w-0">
            <p className="text-[13.5px] font-bold">Build Caches</p>
            <p className="text-[11px] text-[#86868b] tabular-nums dark:text-[#98989d]">
              {scanning || phase === 'idle'
                ? `Scanning · ${files.toLocaleString('en-US')} files`
                : cleared || phase === 'delete'
                  ? 'No items'
                  : `${rows.length} items · ${total.toFixed(1)} GB`}
            </p>
          </div>
          <span className="flex-1" />
          <span ref={selectRef} className={cn(toolButton, cursor.down && phase === 'found' && 'scale-95 bg-black/15 dark:bg-white/20')}>
            Select All Safe
          </span>
          <span className={cn(toolButton, 'hidden lg:inline-flex')}>Deselect All</span>
          <span className={cn(toolButton, 'hidden w-44 gap-1.5 text-[#86868b] lg:inline-flex dark:text-[#98989d]')}>
            <Search className="size-3" /> Filter by name or path
          </span>
          <span
            className="absolute -bottom-px left-0 h-0.5 bg-brand shadow-[0_0_10px_var(--color-brand)] transition-opacity duration-500"
            style={{ width: `${progress * 100}%`, opacity: scanning ? 1 : 0 }}
          />
        </div>

        <div className="grid grid-cols-[34px_minmax(0,1fr)_88px] items-center border-b border-black/[0.06] px-4 text-[11px] font-semibold text-[#86868b] sm:grid-cols-[34px_minmax(0,1fr)_92px_84px] lg:grid-cols-[34px_minmax(0,1fr)_96px_88px_80px] dark:border-white/[0.06] dark:text-[#98989d]">
          <span />
          <span>Name</span>
          <span className="pr-3.5 text-right">Size</span>
          <span className="hidden sm:block">Safety</span>
          <span className="hidden lg:block">Modified</span>
        </div>

        <div className="relative overflow-hidden">
          {rows.map((r, i) => {
            const visible = i < shown && i >= gone;
            const isTicked = i < ticked;
            return (
              <motion.div
                key={r.name}
                initial={false}
                animate={{ opacity: visible ? 1 : 0, height: i < gone ? 0 : 50, x: i < gone ? -14 : 0, y: i < shown ? 0 : 6 }}
                transition={{ duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
                className={cn(
                  'grid grid-cols-[34px_minmax(0,1fr)_88px] items-center overflow-hidden px-4 sm:grid-cols-[34px_minmax(0,1fr)_92px_84px] lg:grid-cols-[34px_minmax(0,1fr)_96px_88px_80px]',
                  i % 2 === 1 && 'bg-black/[0.025] dark:bg-white/[0.025]',
                  isTicked && phase !== 'delete' && 'bg-brand/[0.07] dark:bg-brand/[0.12]',
                )}
              >
                <span
                  className={cn(
                    'grid size-[15px] place-items-center rounded-[4px] border transition-colors duration-200',
                    isTicked ? 'border-brand bg-brand' : 'border-black/25 bg-white dark:border-white/30 dark:bg-white/5',
                  )}
                >
                  <svg viewBox="0 0 24 24" className={cn('size-2.5 text-white transition-all duration-200', isTicked ? 'scale-100 opacity-100' : 'scale-50 opacity-0')} fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                </span>
                <span className="flex min-w-0 items-center gap-2.5">
                  <Folder />
                  <span className="min-w-0">
                    <span className="block truncate font-medium">{r.name}</span>
                    <span className="block truncate text-[11px] text-[#86868b] dark:text-[#98989d]">{r.where}</span>
                  </span>
                </span>
                <span className="pr-3.5 text-right tabular-nums">{fmt(r.size)}</span>
                <span className="hidden sm:block">
                  <span className="inline-flex items-center gap-1 rounded-full bg-safe/12 px-2 py-0.5 text-[11px] font-semibold text-safe">
                    <span className="size-1.5 rounded-full bg-current" />
                    Safe
                  </span>
                </span>
                <span className="hidden text-[12px] text-[#86868b] lg:block dark:text-[#98989d]">{r.when}</span>
              </motion.div>
            );
          })}
          <div className={cn('pointer-events-none absolute inset-0 grid place-content-center justify-items-center gap-2 text-center transition-opacity duration-500', cleared ? 'opacity-100' : 'opacity-0')}>
            <CheckCircle2 className="size-9 text-[#c7c7cc] dark:text-[#5a5a60]" strokeWidth={1.5} />
            <p className="text-[14px] font-semibold">Nothing to Show</p>
            <p className="text-[12px] text-[#86868b] dark:text-[#98989d]">Build Caches is clean.</p>
          </div>
        </div>

        <div className="flex items-center justify-end gap-3 border-t border-black/[0.07] px-4 md:justify-between md:pl-5 dark:border-black/60 dark:bg-[#232326]">
          <span className="hidden text-[12px] text-[#86868b] md:block dark:text-[#98989d]">Ticked items are deleted permanently.</span>
          <span className="flex items-center gap-2">
            <span className={toolButton}>Untick All</span>
            <span
              ref={deleteRef}
              className={cn(
                'inline-flex h-[30px] min-w-[172px] items-center justify-center rounded-lg bg-[#e5484d] px-3.5 text-[12.5px] font-semibold whitespace-nowrap text-white tabular-nums shadow-[inset_0_1px_0_rgb(255_255_255/0.2)] transition-all duration-200',
                ticked === 0 || phase === 'delete' || cleared ? 'opacity-40' : 'opacity-100',
                cursor.down && phase === 'select' && 'scale-95',
              )}
            >
              {ticked === 0 || phase === 'delete' || cleared ? 'Delete 0 items' : `Delete ${ticked} ${ticked === 1 ? 'item' : 'items'} · ${tickedSize.toFixed(1)} GB`}
            </span>
          </span>
        </div>

        {/* Toast */}
        <motion.div
          initial={false}
          animate={{ opacity: cleared ? 1 : 0, y: cleared ? 0 : 14, scale: cleared ? 1 : 0.98 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          className="absolute right-5 bottom-[72px] flex items-center gap-3 rounded-2xl border border-black/10 bg-white/90 py-3 pr-5 pl-3 shadow-[0_20px_40px_-12px_rgb(0_0_0/0.25)] backdrop-blur-xl dark:border-white/12 dark:bg-[#2c2c30]/90 dark:shadow-[0_20px_40px_-10px_rgb(0_0_0/0.6)]"
        >
          <span className="grid size-[30px] place-items-center rounded-[9px] bg-safe/15 text-safe">
            <CheckCircle2 className="size-4" />
          </span>
          <span>
            <span className="block text-[14px] font-semibold">Freed {total.toFixed(1)} GB</span>
            <span className="block text-[11.5px] text-[#86868b] dark:text-[#98989d]">6 items deleted · no confirmation needed</span>
          </span>
        </motion.div>
      </section>

      {/* Pointer */}
      <motion.svg
        viewBox="0 0 24 24"
        className="pointer-events-none absolute top-0 left-0 z-10 size-[22px] drop-shadow-[0_2px_3px_rgb(0_0_0/0.45)]"
        initial={false}
        animate={{ x: cursor.x, y: cursor.y, opacity: cursor.visible ? 1 : 0, scale: cursor.down ? 0.85 : 1 }}
        transition={{ x: { duration: 1, ease: [0.16, 1, 0.3, 1] }, y: { duration: 1, ease: [0.16, 1, 0.3, 1] }, opacity: { duration: 0.3 }, scale: { duration: 0.12 } }}
        aria-hidden="true"
      >
        <path d="M4 2.5v17.2l4.7-4.6 3 6.6 2.9-1.3-3-6.5h6.6z" fill="#fff" stroke="#000" strokeWidth="1.2" strokeLinejoin="round" />
      </motion.svg>
    </div>
  );
}

const toolButton =
  'inline-flex h-7 items-center whitespace-nowrap rounded-lg bg-black/[0.06] px-3 text-[12.5px] font-medium transition-all duration-150 dark:bg-white/[0.09]';

function Lights({ className }: { className?: string }) {
  return (
    <span className={cn('flex gap-2', className)} aria-hidden="true">
      <i className="size-3 rounded-full bg-[#ff5f57] ring-[0.5px] ring-black/20" />
      <i className="size-3 rounded-full bg-[#febc2e] ring-[0.5px] ring-black/20" />
      <i className="size-3 rounded-full bg-[#28c840] ring-[0.5px] ring-black/20" />
    </span>
  );
}

function SideItem({ icon: Icon, label, size, active }: { icon: typeof HardDrive; label: string; size?: string; active?: boolean }) {
  return (
    <div
      className={cn(
        'grid h-[30px] grid-cols-[20px_1fr_auto] items-center gap-2 rounded-[7px] px-2.5',
        active ? 'bg-brand text-white' : 'text-[#1d1d1f] dark:text-[#e5e5ea]',
      )}
    >
      <Icon className={cn('size-4', active ? 'text-white' : 'text-brand dark:text-[#8f8df5]')} strokeWidth={1.8} />
      <span className="truncate">{label}</span>
      {size !== undefined && (
        <span className={cn('text-[11.5px] tabular-nums', active ? 'text-white/85' : 'text-[#86868b] dark:text-[#98989d]')}>{size}</span>
      )}
    </div>
  );
}
