import { source } from '@/lib/source';
import {
  DocsBody,
  DocsDescription,
  DocsPage,
  DocsTitle,
  MarkdownCopyButton,
  ViewOptionsPopover,
} from 'fumadocs-ui/layouts/docs/page';
import { notFound } from 'next/navigation';
import { getMDXComponents } from '@/components/mdx';
import type { Metadata } from 'next';
import { createRelativeLink } from 'fumadocs-ui/mdx';
import { appName, author, getPageImageUrl, getPageMarkdownUrl, gitConfig, repoUrl, siteUrl } from '@/lib/shared';

/** FAQ structured data from the page's `### question` headings and the paragraphs under them. */
function faqJsonLd(markdown: string) {
  const entries = [...markdown.matchAll(/^### (.+)\n+([\s\S]*?)(?=\n#{2,3} |$)/gm)].map(([, q, a]) => ({
    '@type': 'Question',
    name: q.trim(),
    acceptedAnswer: { '@type': 'Answer', text: a.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/[`*]/g, '').trim() },
  }));
  return entries.length ? { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: entries } : null;
}

export default async function Page(props: PageProps<'/docs/[[...slug]]'>) {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const MDX = page.data.body;
  const markdownUrl = getPageMarkdownUrl(page).url;
  const url = `${siteUrl}${page.url}/`;
  const jsonLd: object[] = [
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: appName, item: `${siteUrl}/` },
        { '@type': 'ListItem', position: 2, name: 'Docs', item: `${siteUrl}/docs/` },
        { '@type': 'ListItem', position: 3, name: page.data.title, item: url },
      ],
    },
    {
      '@context': 'https://schema.org',
      '@type': 'TechArticle',
      headline: page.data.title,
      description: page.data.description,
      url,
      author: { '@type': 'Person', name: author },
      about: { '@type': 'SoftwareApplication', name: appName, operatingSystem: 'macOS' },
    },
  ];
  if (page.slugs[0] === 'faq') {
    const faq = faqJsonLd(await page.data.getText('processed'));
    if (faq) jsonLd.push(faq);
  }

  return (
    <DocsPage toc={page.data.toc} full={page.data.full}>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <DocsTitle>{page.data.title}</DocsTitle>
      <DocsDescription className="mb-0">{page.data.description}</DocsDescription>
      <div className="flex flex-row items-center gap-2 border-b pb-6">
        <MarkdownCopyButton markdownUrl={markdownUrl} />
        <ViewOptionsPopover
          markdownUrl={markdownUrl}
          githubUrl={`${repoUrl}/blob/${gitConfig.branch}/website/content/docs/${encodeURI(page.path)}`}
        />
      </div>
      <DocsBody>
        <MDX components={getMDXComponents({ a: createRelativeLink(source, page) })} />
      </DocsBody>
    </DocsPage>
  );
}

export async function generateStaticParams() {
  return source.generateParams();
}

export async function generateMetadata(props: PageProps<'/docs/[[...slug]]'>): Promise<Metadata> {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const image = getPageImageUrl(page).url;
  return {
    title: page.data.title,
    description: page.data.description,
    alternates: { canonical: `${page.url}/` },
    openGraph: { type: 'article', title: `${page.data.title} · ${appName}`, description: page.data.description, url: `${page.url}/`, images: image },
    twitter: { card: 'summary_large_image', title: `${page.data.title} · ${appName}`, description: page.data.description, images: image },
  };
}
