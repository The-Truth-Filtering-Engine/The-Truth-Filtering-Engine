import type { MetadataRoute } from 'next'

const SITE_URL = 'https://truth-filtering-engine-web.vercel.app'

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: SITE_URL,
      lastModified: new Date(),
    },
  ]
}
