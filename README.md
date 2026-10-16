# Mule Box — a Libre Publish theme

[mulebox.com](https://mulebox.com), drawn by Libre Publish from its own
content: the Astro site (Brem-LLC/mulebox) moved into the CMS. It began as a
copy of the [starter theme](https://github.com/Martin-Business-Consultants/libre-publish-theme-starter)
and keeps what that does (the theme's files served by the theme, the forms,
the form emails, the 404, the web manifest, the snapshot task and its spec),
restyled and extended into the Mule Box design.

## What it draws

- **The header** (`website/shared/_header`): the red top bar with Site
  details' line and social links, and on a location's page that location's
  phone; the logo (Settings › Branding), the **Navigation** global (an item
  with links under it opens them in place) and the quote button.
- **The footer** (`_footer`): the **Footer** global's logo, disclaimer, link
  columns, copyright (`{year}` is this year) and legal links, and the social links.
- **Pages** (`website/pages/show`) from blocks. The Astro components, each a
  block type of the theme's (`lib/mulebox/block_types.rb`, category "Mule Box"):

  | Block type | Astro component |
  | --- | --- |
  | `mule_hero` Hero with quote form (slides fade for the home page) | Hero, HeroCarousel, QuoteFormWrapper |
  | `single_hero` Photo banner | HeroTwo |
  | `how_it_works` | Workacross |
  | `title_description` Heading and text | TitleWithDescription |
  | `service_areas` | ServicesAreas |
  | `two_col` Photo and text | TwoCol |
  | `comparison` | Table |
  | `team` | Team |
  | `pricing_factors` | Factors |
  | `faq` (the starter's, restyled) | FaqAccordion |
  | `rich_text` | RichText, and the privacy policy and terms pages |
  | `hourly_movers`, `what_fits_table` | HourlyMovers, WhatFitTable |
  | `quote_section` | QuoteSection (/quote) |
  | `recent_posts` | blog index, RecentPosts |
  | `locations_list` | locations/index |
  | `thank_you` | thank-you, thank-you-franchise |

  The copy those components wrote in (the comparison's rows, the movers, the
  chart, the quote card's small print) is in the blocks' fields. The first
  section that opens a page draws its one h1; a page that opens otherwise
  gets its title as the heading.
- **Locations** (`website/entries/locations`): a collection with blocks, one
  entry per market at `/locations/<slug>`, each with its phone (the top bar),
  its market (its quote forms are filed under it), its photo and order (the
  Locations page).
- **The blog** (`website/entries/blog`): posts at `/blog/<slug>`, newest first.
- **The quote form** (`website/shared/_quote_form`, the Forms plugin's
  "quote"): QuoteForm.svelte's layout — the three services, the name, the
  ZIPs (Move It's relocation ZIP and Store It's indoor/outdoor only for
  them), the box size and day, how to reach them and the SMS consent. It
  posts to the Forms plugin and then goes to Site details › "After a quote
  request" (/quote-thank-you). The Astro site priced quotes live from gofuse;
  that pricing isn't part of the theme. The **franchise** form is drawn by
  the starter's form partial, then goes to /thank-you-franchise.
- **Site details** (the `site` global): the top bar, social links, quote
  button, thank-you pages, the quote card's notes, the default SMS consent
  and the cookie notice (CookieBanner.svelte, kept as `mb_cookie_consent`).
- **Design settings** (Settings › Themes › Customize): the brand red, the
  button teal, the text color, the heading font, the corners, and whether to
  show the cookie banner.

Fonts (Open Sans, Roboto Slab, latin) and the theme's images (logo,
favicon, service icons, comparison logos) are in `app/assets/*/mulebox`.

## The content

The Astro site read nearly everything from a Directus CMS at request time,
and only its posts are public there, so the content was read back from the
deployed site:

    bundle exec ruby ../mulebox-theme/script/scrape-live   # → script/data/live.json
    ruby ../mulebox-theme/script/fetch-media               # → script/media, script/data/media.json
    bin/rails runner themes/mulebox/script/import.rb       # into the CMS, as often as you like

The import (on `script/import/kit.rb`) makes the block types, the Blog and
Locations collections, every page, location and post, the Navigation,
Footer, Site details and Scripts (Google Tag Manager) globals, the quote and
franchise forms with their emails, Settings › General and Branding, and the
redirects for addresses that have no page of their own (`/thank-you`,
`/quote-thank-you/<market>`).

## Check it

    bin/rails mulebox:snapshot                              # the content the spec draws
    bin/rspec themes/mulebox/spec
    bundle exec herb lint themes/mulebox --fail-level warning
    bin/rubocop themes/mulebox
    bundle exec brakeman --add-engines-path themes/mulebox

`spec/requests/website_spec.rb` is the starter's (every page, entry, block
type and form); `spec/requests/mulebox_spec.rb` checks the site's own
pieces. The system specs start headless Chrome with
`spec/support/mulebox_browser.rb` where the machine needs it.

## Release it

The repository is `Martin-Business-Consultants/mulebox-theme`. Bump
`lib/mulebox/version.rb`, tag `v<version>`, and publish a GitHub release.
Sites using the theme see the update in Settings › Themes. If the site has
Settings › Security policy on, allow Turnstile (`challenges.cloudflare.com`)
or reCAPTCHA there for its forms, and Google Tag Manager for its Scripts.
