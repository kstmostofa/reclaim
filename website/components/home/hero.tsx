'use client';
import Link from 'next/link';
import { useRef } from 'react';
import { motion, useReducedMotion, useScroll, useTransform } from 'motion/react';
import { ArrowRight, Download } from 'lucide-react';
import { AppWindow } from './app-window';
import { downloadUrl, version } from '@/lib/shared';

const ease = [0.16, 1, 0.3, 1] as const;

function Words({ text, delay, className }: { text: string; delay: number; className?: string }) {
  const reduce = useReducedMotion();
  return (
    <span className={`block ${className ?? ''}`}>
      {text.split(' ').map((word, i) => (
        <span key={i} className="inline-block overflow-hidden pb-[0.08em] align-bottom">
          <motion.span
            className="inline-block"
            initial={reduce ? false : { y: '110%' }}
            animate={{ y: 0 }}
            transition={{ duration: 1.1, delay: delay + i * 0.06, ease }}
          >
            {word}
            {' '}
          </motion.span>
        </span>
      ))}
    </span>
  );
}

export function Hero() {
  const reduce = useReducedMotion();
  const stage = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: stage, offset: ['start end', 'start 0.25'] });
  const rotateX = useTransform(scrollYProgress, [0, 1], [reduce ? 0 : 22, 0]);
  const scale = useTransform(scrollYProgress, [0, 1], [reduce ? 1 : 0.9, 1]);
  const y = useTransform(scrollYProgress, [0, 1], [reduce ? 0 : 60, 0]);

  return (
    <section className="relative isolate overflow-x-clip pt-32 md:pt-40">
      <div className="hairlines absolute inset-0 -z-10" />
      <div className="toplight absolute -top-[480px] left-1/2 -z-10 h-[1000px] w-[1400px] -translate-x-1/2" />

      <div className="mx-auto max-w-6xl px-6 text-center">
        <motion.a
          href={downloadUrl}
          initial={reduce ? false : { opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease }}
          className="glass mb-10 inline-flex h-9 items-center gap-2.5 rounded-full py-1 pr-4 pl-1.5 text-sm text-fd-muted-foreground transition-colors hover:text-fd-foreground"
        >
          <span className="rounded-full bg-brand px-2.5 py-0.5 text-sm font-semibold text-white">v{version}</span>
          Free and open source for macOS
          <ArrowRight className="size-3.5" />
        </motion.a>

        <h1 className="display mx-auto max-w-6xl text-[clamp(3.6rem,8.8vw,8.25rem)]">
          <Words text="Take back your disk." delay={0.1} />
          <Words text="Keep what matters." delay={0.3} className="text-fd-muted-foreground" />
        </h1>

        <motion.p
          initial={reduce ? false : { opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, delay: 0.55, ease }}
          className="mx-auto mt-8 max-w-2xl text-lg leading-relaxed text-fd-muted-foreground md:text-xl"
        >
          Reclaim finds the build caches, dependencies, simulators and Docker leftovers filling your Mac, tells you what's
          safe to delete, and frees the space in one click.
        </motion.p>

        <motion.div
          initial={reduce ? false : { opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, delay: 0.7, ease }}
          className="mt-10 flex flex-wrap justify-center gap-3"
        >
          <a href={downloadUrl} className="glass-tint inline-flex h-12 items-center gap-2 rounded-full px-6 font-display text-lg font-semibold">
            <Download className="size-4" />
            Download for Mac
          </a>
          <Link href="/docs" className="glass-btn group inline-flex h-12 items-center gap-2 rounded-full px-6 font-display text-lg font-semibold">
            Read the docs
            <ArrowRight className="size-4 transition-transform group-hover:translate-x-0.5" />
          </Link>
        </motion.div>
        <motion.p
          initial={reduce ? false : { opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1, delay: 0.9 }}
          className="mt-6 text-[17px] tracking-wide text-fd-muted-foreground"
        >
          macOS 14+ · Apple silicon &amp; Intel · MIT license
        </motion.p>
      </div>

      <div ref={stage} className="mx-auto mt-16 max-w-[1240px] px-4 [perspective:2400px] md:mt-20 md:px-6">
        <motion.div style={{ rotateX, scale, y, transformOrigin: '50% 0%' }} className="relative">
          <div className="absolute inset-x-[12%] -top-10 -z-10 h-56 rounded-full bg-brand/25 blur-[90px] dark:bg-brand/30" />
          <AppWindow />
        </motion.div>
      </div>
    </section>
  );
}
