# Tech Stack Setup

Reference for project scaffolding, configuration, and infrastructure patterns. Load this during the Foundation phase.

## Astro Project Scaffold

Astro is the recommended framework for B2B landing pages — static-first, fast, and ships zero JS by default.

### Initialize

```bash
npm create astro@latest -- --template minimal --no-install project-name
cd project-name
npm install
npm install @astrojs/tailwind tailwindcss
```

### Project Structure

```
src/
├── layouts/
│   └── Layout.astro          # Base HTML layout with <head>, fonts, OG tags
├── pages/
│   └── index.astro           # Landing page entry point
├── components/
│   ├── sections/             # Page sections (Hero, ValueProps, HowItWorks, etc.)
│   ├── ui/                   # Reusable UI elements (Button, Card, Badge, etc.)
│   ├── Header.astro
│   └── Footer.astro
├── lib/
│   └── copy.ts               # Centralized copy content
├── assets/
│   └── images/               # Optimized images (Astro handles optimization)
└── styles/
    └── global.css             # Global styles and Tailwind directives
```

### astro.config.mjs

```javascript
import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  integrations: [tailwind()],
  site: 'https://your-domain.com',
});
```

## Tailwind CSS Configuration

### Design Tokens Pattern

Define design tokens in `tailwind.config.mjs`. Extend — do not override — the default theme.

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        // Define brand colors as semantic tokens
        brand: {
          50: '#f0f9ff',
          // ... full scale
          900: '#0c4a6e',
        },
        surface: {
          primary: 'var(--surface-primary)',
          secondary: 'var(--surface-secondary)',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['Cal Sans', 'Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      fontSize: {
        // Custom scale for landing pages (larger than defaults)
        'display-lg': ['4.5rem', { lineHeight: '1.1', letterSpacing: '-0.02em' }],
        'display': ['3.5rem', { lineHeight: '1.15', letterSpacing: '-0.02em' }],
        'display-sm': ['2.5rem', { lineHeight: '1.2', letterSpacing: '-0.01em' }],
      },
      spacing: {
        'section': '6rem',
        'section-lg': '8rem',
      },
      maxWidth: {
        'content': '64rem',
        'narrow': '48rem',
      },
    },
  },
  plugins: [],
};
```

### Global CSS

```css
/* src/styles/global.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --surface-primary: theme('colors.white');
    --surface-secondary: theme('colors.gray.50');
  }

  .dark {
    --surface-primary: theme('colors.gray.950');
    --surface-secondary: theme('colors.gray.900');
  }

  html {
    scroll-behavior: smooth;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }
}
```

## Centralized Copy Pattern

Keep all user-facing text in a single file. This enables easy review, translation, and variant reuse.

### lib/copy.ts

```typescript
export const copy = {
  meta: {
    title: 'Product Name — One-line value prop',
    description: 'SEO meta description (150-160 chars)',
    ogImage: '/og-image.png',
  },
  nav: {
    logo: 'ProductName',
    links: [
      { label: 'Features', href: '#features' },
      { label: 'Pricing', href: '#pricing' },
      { label: 'Docs', href: '/docs' },
    ],
    cta: { label: 'Get Started', href: '/signup' },
    signIn: { label: 'Sign in', href: '/login' },
  },
  hero: {
    headline: 'Clear, specific headline',
    subheadline: 'One sentence expanding on the headline',
    primaryCta: { label: 'Start Building', href: '/signup' },
    secondaryCta: { label: 'View Demo', href: '#demo' },
  },
  // ... sections follow the same pattern
} as const;
```

Usage in components:

```astro
---
import { copy } from '../lib/copy';
---
<h1>{copy.hero.headline}</h1>
```

## Cloudflare Pages Setup

### wrangler.toml

```toml
name = "project-name"
compatibility_date = "2025-01-01"
pages_build_output_dir = "./dist"
```

### Deploy Commands

```bash
# Install wrangler
npm install -D wrangler

# Preview locally
npx wrangler pages dev ./dist

# Deploy
npx wrangler pages deploy ./dist
```

### Custom Domain

Configure in Cloudflare dashboard: Workers & Pages → project → Custom domains.

## Component Architecture

### Section Components

Each page section is a self-contained component:

```astro
---
// src/components/sections/Hero.astro
import { copy } from '../../lib/copy';
import Button from '../ui/Button.astro';
---

<section id="hero" class="py-section lg:py-section-lg">
  <div class="mx-auto max-w-content px-6">
    <h1 class="text-display-lg font-display font-bold">
      {copy.hero.headline}
    </h1>
    <p class="mt-6 max-w-narrow text-xl text-gray-400">
      {copy.hero.subheadline}
    </p>
    <div class="mt-10 flex gap-4">
      <Button href={copy.hero.primaryCta.href} variant="primary">
        {copy.hero.primaryCta.label}
      </Button>
      <Button href={copy.hero.secondaryCta.href} variant="ghost">
        {copy.hero.secondaryCta.label}
      </Button>
    </div>
  </div>
</section>
```

### Layout Component

```astro
---
// src/layouts/Layout.astro
import { copy } from '../lib/copy';
import '../styles/global.css';

interface Props {
  title?: string;
  description?: string;
}

const { title = copy.meta.title, description = copy.meta.description } = Astro.props;
---

<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content={copy.meta.ogImage} />
    <meta name="twitter:card" content="summary_large_image" />
    <link rel="sitemap" href="/sitemap-index.xml" />
  </head>
  <body>
    <slot />
  </body>
</html>
```

## SEO Infrastructure Checklist

Complete these before shipping:

- [ ] **Page title** — `<title>` with product name and value prop (under 60 chars)
- [ ] **Meta description** — 150-160 chars, includes primary keyword and CTA
- [ ] **OG tags** — og:title, og:description, og:image, og:url, og:type
- [ ] **Twitter card** — twitter:card, twitter:title, twitter:description, twitter:image
- [ ] **Canonical URL** — `<link rel="canonical" href="...">`
- [ ] **Sitemap** — Auto-generated by Astro with `@astrojs/sitemap`
- [ ] **robots.txt** — Allow all by default, add to `public/robots.txt`
- [ ] **Structured data** — JSON-LD for Organization and Product (in `<head>`)
- [ ] **Favicon** — Multiple sizes in `public/` (favicon.ico, apple-touch-icon.png, etc.)
- [ ] **Performance** — Lighthouse score above 90 for Performance, Accessibility, SEO
- [ ] **Image optimization** — Use Astro's `<Image>` component for automatic optimization
- [ ] **Font loading** — Use `font-display: swap` and preload critical fonts

## Alternative: Plain HTML + Tailwind

For projects that do not need a build step:

```bash
# Use Tailwind CLI
npm install -D tailwindcss
npx tailwindcss init
```

Create a single `index.html` with `<link>` to compiled CSS. Run Tailwind in watch mode:

```bash
npx tailwindcss -i ./src/input.css -o ./dist/output.css --watch
```

## Alternative: 11ty (Eleventy)

For markdown-heavy landing pages:

```bash
npm install -D @11ty/eleventy
```

Use `.njk` templates with Tailwind. 11ty is simpler but has a smaller ecosystem than Astro.
