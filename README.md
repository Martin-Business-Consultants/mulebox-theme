# Libre Publish theme mulebox

Every Libre Publish theme starts as a copy of this one. It does what every
site needs, the way the CMS expects it, so a theme only adds its own design
and sections:

- **Its own files, served by the theme** at `/_<theme>/<name>` with a digest
  (`app/controllers/<theme>/assets_controller.rb`): no asset pipeline, so
  it works whether it came with the install or from Settings › Plugins.
  Stylesheets, fonts and images go in `app/assets/{stylesheets,fonts,images}/<theme>/`,
  scripts in `app/javascript/<theme>/` (site.js imports the rest).
- **A helper** (`app/helpers/<theme>_helper.rb`): the site's name, links
  without the preview's inline-edit marks, phone links, the title, favicon
  and logo from Settings › Branding, and the forms.
- **The nav and footer** from their globals, and a layout that still draws
  before a site's content is in.
- **A partial for every core block type**, and two block types of its own,
  installed when the theme is switched on: **Form** (any of the site's
  forms) and **FAQ** (with its FAQPage data).
- **Forms**: one partial for every form the Forms plugin holds, every field
  type, the honeypot, Turnstile or reCAPTCHA as Settings › Forms has them,
  the visit's attribution (UTM tags, click ids, landing page) for the fields
  that keep it, sent in place by `forms.js`, with the plugin's answer shown
  beside the fields. The form **emails** in the site's colors.
- **The 404** (the site's not-found page when it has one), the **web
  manifest**, a skip link, `lang` from what's shown.
- **A spec** (`spec/requests/website_spec.rb`) that draws every page, entry,
  block type and form, and a **snapshot task** (`bin/rails <theme>:snapshot`)
  so it draws the site's real content.
- **An import kit** (`script/import/kit.rb`) for bringing a site's content
  in: field types inferred from the content, lists included, and upserts for
  block types, collections, entries, pages and globals.

## Start a theme

In a Libre Publish checkout:

    bin/theme new acme            # clones this into ../acme-theme, renames it, links it in
    bin/pull production           # the live site's content, locally (or script/import.rb, for a new site)
    bin/dev                       # http://localhost:3000

Edit `app/views` and `app/assets/stylesheets/acme/site.css`; the site
reloads as you save. Restyle and extend what's here rather than writing it
again. A field that holds a list is a `string_list` or a `repeater`, never a
`string`. The whole story, from pulling a site to releasing the theme, is in
the CMS's docs: [Local development](https://martin-business-consultants.github.io/libre-publish/local-development.html).

## Check it

    bin/rails acme:snapshot                             # the content the spec draws
    bin/rspec themes/acme/spec
    bundle exec herb lint themes/acme --fail-level warning
    bin/rubocop themes/acme

## Release it

The repository is `<org>/<name>-theme` (bin/fetch-theme names the theme from
it). Bump `lib/<theme>/version.rb`, tag `v<version>` (the CMS compares the
two), and publish a GitHub release. Sites using the theme see the update in
Settings › Themes. If the site has Settings › Security policy on, allow
Turnstile (`challenges.cloudflare.com`) or reCAPTCHA there for its forms.
