import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { LogoMark } from '@/components/logo';
import { appName, repoUrl } from './shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="flex items-center gap-2.5 text-[15px] font-semibold tracking-tight">
          <LogoMark className="size-[22px]" />
          {appName}
        </span>
      ),
    },
    githubUrl: repoUrl,
    links: [
      { text: 'Docs', url: '/docs', active: 'nested-url' },
      { text: 'What it finds', url: '/docs/what-it-finds' },
      { text: 'FAQ', url: '/docs/faq' },
    ],
  };
}
