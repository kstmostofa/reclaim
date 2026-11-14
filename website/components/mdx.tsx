import defaultMdxComponents from 'fumadocs-ui/mdx';
import { Step, Steps } from 'fumadocs-ui/components/steps';
import { Accordion, Accordions } from 'fumadocs-ui/components/accordion';
import { Tab, Tabs } from 'fumadocs-ui/components/tabs';
import type { MDXComponents } from 'mdx/types';
import { asset } from '@/lib/shared';
import { cn } from '@/lib/cn';

/** Safe, Rebuild or Personal. */
export function Level({ of }: { of: 'safe' | 'rebuild' | 'personal' }) {
  const styles = {
    safe: 'text-safe bg-safe/10',
    rebuild: 'text-rebuild bg-rebuild/10',
    personal: 'text-personal bg-personal/10',
  }[of];
  return (
    <span className={cn('inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-semibold whitespace-nowrap', styles)}>
      <span className="size-1.5 rounded-full bg-current" />
      {of[0].toUpperCase() + of.slice(1)}
    </span>
  );
}

/** An app screenshot in a window frame; with `dark`, the dark-mode capture shows in dark mode. */
export function Screenshot({ src, dark, alt, narrow }: { src: string; dark?: string; alt: string; narrow?: boolean }) {
  const frame = 'not-prose shot block';
  return (
    <figure className={cn('my-8', narrow && 'max-w-md')}>
      <img src={asset(`/screenshots/${src}`)} alt={alt} loading="lazy" className={cn(frame, dark && 'dark:hidden')} />
      {dark && <img src={asset(`/screenshots/${dark}`)} alt={alt} loading="lazy" className={cn(frame, 'hidden dark:block')} />}
    </figure>
  );
}

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    Step,
    Steps,
    Accordion,
    Accordions,
    Tab,
    Tabs,
    Level,
    Screenshot,
    ...components,
  } satisfies MDXComponents;
}

export const useMDXComponents = getMDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
