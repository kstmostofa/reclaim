'use client';
import { useRef } from 'react';
import { motion, useMotionValueEvent, useReducedMotion, useScroll, useTransform, type MotionValue } from 'motion/react';
import { useState } from 'react';

/**
 * Apple-style pinned story. The section is three screens tall; its visual stays put while three chapters
 * pass: the pie is scanned, its parts are labelled, then the reclaimable slice is pulled out.
 */

const chapters = [
  {
    kicker: '01 — Scan',
    title: 'Every folder. In about a minute.',
    body: 'Reclaim walks the whole disk in parallel, measuring the space files really use. Hard links count once, sparse disk images count what they occupy, and other drives are left alone.',
  },
  {
    kicker: '02 — Understand',
    title: 'Know what it is before it goes.',
    body: 'Every suggestion says what it is, why it is listed and what happens after. Safe items rebuild themselves. Rebuild and Personal items wait for your decision.',
  },
  {
    kicker: '03 — Reclaim',
    title: 'One click. Space back.',
    body: 'No dialog for every file. Ticked items go at once, or to the Trash if you prefer, and you get a summary of anything that could not be removed.',
  },
];

const R = 250;
const cx = 495.7;
const cy = 528.3;

export function Story() {
  const reduce = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end end'] });
  const [active, setActive] = useState(0);
  useMotionValueEvent(scrollYProgress, 'change', (v) => setActive(v < 0.34 ? 0 : v < 0.67 ? 1 : 2));

  // Chapter 1: a scan sweep around the pie.
  const sweep = useTransform(scrollYProgress, [0.02, 0.3], [0, 1]);
  const sweepOpacity = useTransform(scrollYProgress, [0.28, 0.36], [1, 0]);
  // Chapter 2: labels.
  const labels = useTransform(scrollYProgress, [0.36, 0.46, 0.62, 0.7], [0, 1, 1, 0]);
  // Chapter 3: the slice pulls out; the total appears.
  const pull = useTransform(scrollYProgress, [0.68, 0.86], [0, 1]);
  const sliceX = useTransform(pull, [0, 1], [-32.6, 40]);
  const sliceY = useTransform(pull, [0, 1], [32.6, -40]);
  const freed = useTransform(scrollYProgress, [0.78, 0.92], [0, 1]);

  return (
    <section ref={ref} className="relative h-[300vh]" aria-label="How Reclaim works">
      <div className="sticky top-0 flex h-screen items-center overflow-hidden">
        <div className="mx-auto grid w-full max-w-6xl items-center gap-12 px-6 md:grid-cols-2">
          <div className="relative min-h-[380px] md:min-h-[360px]">
            {chapters.map((c, i) => (
              <motion.div
                key={c.kicker}
                className="absolute inset-0"
                initial={false}
                animate={{ opacity: active === i ? 1 : 0, y: reduce ? 0 : active === i ? 0 : active > i ? -30 : 30 }}
                transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                aria-hidden={active !== i}
              >
                <p className="eyebrow mb-5">{c.kicker}</p>
                <h2 className="display text-[clamp(3rem,6.4vw,5.5rem)]">{c.title}</h2>
                <p className="mt-6 max-w-md text-lg leading-relaxed text-fd-muted-foreground">{c.body}</p>
              </motion.div>
            ))}
            <div className="absolute -bottom-14 left-0 flex gap-2">
              {chapters.map((c, i) => (
                <span key={c.kicker} className={`h-1 rounded-full transition-all duration-500 ${active === i ? 'w-10 bg-fd-foreground' : 'w-4 bg-fd-border'}`} />
              ))}
            </div>
          </div>

          <div className="relative mx-auto aspect-square w-full max-w-[380px] md:max-w-[420px]">
            <svg viewBox="200 200 620 620" className="size-full overflow-visible">
              <Sweep progress={sweep} opacity={sweepOpacity} />
              <path d={`M${cx} ${cy}H${cx + R}A${R} ${R} 0 1 1 ${cx} ${cy - R}Z`} className="fill-fd-foreground" />
              <motion.path
                d={`M528.3 495.7V245.7A250 250 0 0 1 778.3 495.7Z`}
                fill="var(--color-brand)"
                style={{ x: sliceX, y: sliceY }}
              />
            </svg>
            <motion.div style={{ opacity: labels }} className="pointer-events-none absolute inset-0">
              <Label className="top-[8%] right-[2%]" dot="bg-safe" text="Safe · 12.1 GB" />
              <Label className="bottom-[22%] left-[-4%]" dot="bg-rebuild" text="Rebuild · 17.3 GB" />
              <Label className="bottom-[2%] right-[14%]" dot="bg-personal" text="Personal · 3.4 GB" />
            </motion.div>
            <motion.div style={{ opacity: freed }} className="absolute inset-x-0 top-full mt-2 text-center">
              <p className="display text-6xl tabular-nums md:text-7xl">12.1 GB</p>
              <p className="eyebrow mt-2">freed</p>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Sweep({ progress, opacity }: { progress: MotionValue<number>; opacity: MotionValue<number> }) {
  return (
    <motion.circle
      cx={cx}
      cy={cy}
      r={R + 40}
      fill="none"
      strokeWidth={6}
      strokeLinecap="round"
      className="stroke-brand"
      style={{ pathLength: progress, opacity, rotate: -90, transformOrigin: `${cx}px ${cy}px` }}
    />
  );
}

function Label({ className, dot, text }: { className: string; dot: string; text: string }) {
  return (
    <span className={`absolute inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-background/80 px-3 py-1.5 text-sm font-medium backdrop-blur ${className}`}>
      <span className={`size-2 rounded-full ${dot}`} />
      {text}
    </span>
  );
}
