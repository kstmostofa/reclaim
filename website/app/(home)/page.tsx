import { Hero } from '@/components/home/hero';
import { Story } from '@/components/home/story';
import { Cta, Faq, Features, Figures, Footer, Marquee, Tour } from '@/components/home/sections';
import { faqs } from '@/lib/faqs';
import { appName, author, downloadUrl, repoUrl, siteUrl, version } from '@/lib/shared';

const jsonLd = [
  {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: appName,
    description:
      'Reclaim scans your whole Mac, explains what is safe to delete — build caches, node_modules, app caches, Docker leftovers, duplicates — and removes what you tick in one click.',
    applicationCategory: 'UtilitiesApplication',
    operatingSystem: 'macOS 14 or later',
    softwareVersion: version,
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    license: 'https://opensource.org/licenses/MIT',
    downloadUrl,
    codeRepository: repoUrl,
    url: `${siteUrl}/`,
    author: { '@type': 'Person', name: author },
  },
  { '@context': 'https://schema.org', '@type': 'WebSite', name: appName, url: `${siteUrl}/` },
  {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((f) => ({ '@type': 'Question', name: f.q, acceptedAnswer: { '@type': 'Answer', text: f.a } })),
  },
];

export default function HomePage() {
  return (
    <main className="grain">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <Hero />
      <Marquee />
      <Story />
      <Figures />
      <Features />
      <Tour />
      <Faq />
      <Cta />
      <Footer />
    </main>
  );
}
