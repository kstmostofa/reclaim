import type { MetadataRoute } from 'next';
import { appName, tagline } from '@/lib/shared';

export const dynamic = 'force-static';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: `${appName} — ${tagline}`,
    short_name: appName,
    description: tagline,
    start_url: '/',
    display: 'standalone',
    background_color: '#000000',
    theme_color: '#5856d6',
    icons: [
      { src: '/icon.svg', sizes: 'any', type: 'image/svg+xml' },
      { src: '/apple-icon.png', sizes: '180x180', type: 'image/png' },
    ],
  };
}
