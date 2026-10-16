# frozen_string_literal: true

# The theme's own vocabulary on top of the CMS's WebsiteHelper, what every
# theme needs: its files at the address the theme serves them from, the
# site's name and contact details, links, the title and favicon, and the
# forms. Each helper is named for the theme, so two themes linked side by
# side never shadow each other's.
module MuleboxHelper
  # Inline editing (the editor's preview) marks editable text with invisible
  # characters; an address or a phone number can't carry them.
  INLINE_EDIT_MARKS = [Website::InlineEdit::START, Website::InlineEdit::FINISH, *Website::InlineEdit::DIGITS].join.freeze
  # The attribution a form keeps, for the fields its form declares
  # (forms.js fills them from the visit).
  ATTRIBUTION = %w[utm_source utm_medium utm_campaign utm_term utm_content gclid fbclid msclkid landing_path referrer form_path].freeze
  DIGESTS = {} # rubocop:disable Style/MutableConstant

  # ── The theme's files ──

  # A file of the theme's ("site.css", "logo.png") at the address the theme
  # serves it from (Mulebox::AssetsController), with its digest so it can be
  # cached for good.
  def mulebox_asset_path(name)
    file = Mulebox::AssetsController.find(name) or raise ArgumentError, "the theme has no file #{name} (app/assets/*/mulebox, app/javascript/mulebox)"
    digest = Rails.env.production? ? (DIGESTS[name] ||= mulebox_digest(file)) : mulebox_digest(file)
    "/_mulebox/#{name}?v=#{digest}"
  end

  # The theme's scripts as ES modules (every .js in app/javascript/mulebox),
  # each preloaded, then site.js, which imports the rest. Its own importmap:
  # none of the admin's scripts reach a visitor.
  def mulebox_javascript_tags
    modules = Mulebox::AssetsController.files.keys.select { it.end_with?(".js") }.sort
    imports = modules.to_h { ["mulebox/#{it.delete_suffix(".js")}", mulebox_asset_path(it)] }
    nonce = content_security_policy_nonce
    safe_join([
      tag.script(ERB::Util.json_escape({imports:}.to_json).html_safe, type: "importmap", nonce:), # rubocop:disable Rails/OutputSafety -- our own paths, JSON-escaped
      *imports.values.map { tag.link(rel: "modulepreload", href: it, nonce:) },
      tag.script('import "mulebox/site"'.html_safe, type: "module", nonce:) # rubocop:disable Rails/OutputSafety -- a constant
    ], "\n")
  end

  # ── The site ──

  def mulebox_name = website_settings["title"].presence || "Home"

  # The "site" global (Site details): the top bar, the social links, the
  # quote button and the copy every quote form shares. Nil on a fresh site.
  def mulebox_site = mulebox_global(:site)

  # A Site details field, or `fallback` when the site has none.
  def mulebox_site_value(name, fallback = nil) = mulebox_site&.[](name).presence || fallback

  # ── Locations ──

  # The location a page belongs to (a Locations entry, set by its template),
  # for the top bar's phone and the market its quote forms file under.
  def mulebox_location = @mulebox_location

  def mulebox_location_fields = mulebox_location && website_fields(mulebox_location)

  # ── Headings ──

  # The sections that open a page draw its one h1 (the first of them on a
  # page does; the rest an h2). A page that opens with anything else gets its
  # title as the h1 (website/pages/show).
  OPENERS = %w[hero mule_hero single_hero quote_section thank_you locations_list hourly_movers recent_posts].freeze

  def mulebox_opener?(block) = OPENERS.include?(block.to_h["type"].to_s)

  def mulebox_heading_tag
    return :h2 if @mulebox_h1

    @mulebox_h1 = true
    :h1
  end

  # The page's <title>: its SEO title as written, else "<title> | <site>".
  def mulebox_seo_tags(record = nil, title: nil, **options)
    own = record.respond_to?(:seo) && record.seo.to_h["meta_title"].presence
    title ||= own || [record.try(:title).presence, mulebox_name].compact.uniq.join(" | ")
    website_seo_tags(record, title:, **options)
  end

  # The language of what's shown: the record's own locale, else the site's.
  def mulebox_locale(record = nil) = record.try(:locale).presence || website_settings["default_locale"].presence || "en"

  # Settings › Branding's favicon, else the theme's own.
  def mulebox_favicon_href
    id = Setting.get("branding")["favicon_id"].presence
    (id && website_image_url(id, width: 192)) || mulebox_asset_path("favicon.png")
  end

  # Settings › Branding's logo, or nil (the header then shows the name).
  def mulebox_logo_id = Setting.get("branding")["logo_id"].presence

  # ── Icons ──

  # The marks the Astro site took from Font Awesome, drawn inline (no icon
  # font to load): the social networks, the phone, the menu and the carets.
  ICONS = {
    phone: ["0 0 512 512", "M164.9 24.6c-7.7-18.6-28-28.5-47.4-23.2l-88 24C12.1 30.2 0 46 0 64c0 247.4 200.6 448 448 448 18 0 33.8-12.1 38.6-29.5l24-88c5.3-19.4-4.6-39.7-23.2-47.4l-96-40c-16.3-6.8-35.2-2.1-46.3 11.6L304.7 368C234.3 334.7 177.3 277.7 144 207.3l49.3-40.3c13.7-11.2 18.4-30 11.6-46.3l-40-96z"],
    caret: ["0 0 20 20", "M10 14l-6-6h12l-6 6z"],
    chevron: ["0 0 512 512", "M233.4 406.6c12.5 12.5 32.8 12.5 45.3 0l192-192c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L256 338.7 86.6 169.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l192 192z"],
    menu: ["0 0 24 24", "M3 6h18v2H3zm0 5h18v2H3zm0 5h18v2H3z"],
    facebook: ["0 0 320 512", "M80 299.3V512h116V299.3h86.5l18-97.8H196v-34.6c0-51.7 20.3-71.5 72.7-71.5 16.3 0 29.4.4 37 1.2V7.9C291.4 4 256.4 0 236.2 0 129.3 0 80 50.5 80 159.4v42.1H14v97.8h66z"],
    instagram: ["0 0 448 512", "M224.1 141c-63.6 0-114.9 51.3-114.9 114.9s51.3 114.9 114.9 114.9S339 319.5 339 255.9 287.7 141 224.1 141zm0 189.6c-41.1 0-74.7-33.5-74.7-74.7s33.5-74.7 74.7-74.7 74.7 33.5 74.7 74.7-33.6 74.7-74.7 74.7zm146.4-194.3c0 14.9-12 26.8-26.8 26.8-14.9 0-26.8-12-26.8-26.8s12-26.8 26.8-26.8 26.8 12 26.8 26.8zm76.1 27.2c-1.7-35.9-9.9-67.7-36.2-93.9-26.2-26.2-58-34.4-93.9-36.2-37-2.1-147.9-2.1-184.9 0-35.8 1.7-67.6 9.9-93.9 36.1s-34.4 58-36.2 93.9c-2.1 37-2.1 147.9 0 184.9 1.7 35.9 9.9 67.7 36.2 93.9s58 34.4 93.9 36.2c37 2.1 147.9 2.1 184.9 0 35.9-1.7 67.7-9.9 93.9-36.2 26.2-26.2 34.4-58 36.2-93.9 2.1-37 2.1-147.8 0-184.8zM398.8 388c-7.8 19.6-22.9 34.7-42.6 42.6-29.5 11.7-99.5 9-132.1 9s-102.7 2.6-132.1-9c-19.6-7.8-34.7-22.9-42.6-42.6-11.7-29.5-9-99.5-9-132.1s-2.6-102.7 9-132.1c7.8-19.6 22.9-34.7 42.6-42.6 29.5-11.7 99.5-9 132.1-9s102.7-2.6 132.1 9c19.6 7.8 34.7 22.9 42.6 42.6 11.7 29.5 9 99.5 9 132.1s2.7 102.7-9 132.1z"],
    youtube: ["0 0 576 512", "M549.7 124.1c-6.3-23.7-24.8-42.3-48.3-48.6C458.8 64 288 64 288 64S117.2 64 74.6 75.5c-23.5 6.3-42 24.9-48.3 48.6C14.9 167 14.9 256.4 14.9 256.4s0 89.4 11.4 132.3c6.3 23.6 24.8 41.5 48.3 47.8C117.2 448 288 448 288 448s170.8 0 213.4-11.5c23.5-6.3 42-24.2 48.3-47.8 11.4-42.9 11.4-132.3 11.4-132.3s0-89.4-11.4-132.3zM232.2 337.6V175.2l142.7 81.2-142.7 81.2z"],
    linkedin: ["0 0 448 512", "M100.3 448H7.4V148.9h92.9zM53.8 108.1C24.1 108.1 0 83.5 0 53.8a53.8 53.8 0 0 1 107.6 0c0 29.7-24.1 54.3-53.8 54.3zM447.9 448h-92.7V302.4c0-34.7-.7-79.2-48.3-79.2-48.3 0-55.7 37.7-55.7 76.7V448h-92.8V148.9h89.1v40.8h1.3c12.4-23.5 42.7-48.3 87.9-48.3 94 0 111.3 61.9 111.3 142.3V448z"],
    pinterest: ["0 0 384 512", "M204 6.5C101.4 6.5 0 74.9 0 185.6 0 256 39.6 296 63.6 296c9.9 0 15.6-27.6 15.6-35.4 0-9.3-23.7-29.1-23.7-67.8 0-80.4 61.2-137.4 140.4-137.4 68.1 0 118.5 38.7 118.5 109.8 0 53.1-21.3 152.7-90.3 152.7-24.9 0-46.2-18-46.2-43.8 0-37.8 26.4-74.4 26.4-113.4 0-66.2-93.9-54.2-93.9 25.8 0 16.8 2.1 35.4 9.6 50.7-13.8 59.4-42 147.9-42 209.1 0 18.9 2.7 37.5 4.5 56.4 3.4 3.8 1.7 3.4 6.9 1.5 50.4-69 48.6-82.5 71.4-172.8 12.3 23.4 44.1 36 69.3 36 106.2 0 153.9-103.5 153.9-196.8C384 71.3 298.2 6.5 204 6.5z"]
  }.freeze

  # An icon by name, decorative (its link or button says what it is).
  def mulebox_icon(name, **options)
    icon = ICONS[name.to_sym] or return
    view_box, path = icon
    tag.svg(tag.path(d: path), xmlns: "http://www.w3.org/2000/svg", viewBox: view_box, fill: "currentColor", "aria-hidden": "true",
      focusable: "false", class: ["icon", "icon--#{name}", options[:class]].compact.join(" "))
  end

  # ── Links and contact details ──

  # An href from a link field ({kind, value}) or a plain string, without the
  # preview's inline-edit marks. Nothing for an empty or unsafe one.
  def mulebox_href(link)
    link = {"kind" => "url", "value" => link} if link.is_a?(String)
    link = link.to_h.stringify_keys
    website_href(link.merge("value" => mulebox_plain(link["value"])))
  end

  def mulebox_plain(text) = text.to_s.delete(INLINE_EDIT_MARKS).strip

  def mulebox_external?(href) = href.to_s.match?(%r{\Ahttps?://}) && !href.to_s.start_with?(website_url("/"))

  # A link that opens elsewhere in a new tab, and says so to a screen reader.
  def mulebox_link_to(label, href, **options)
    return if href.blank?
    return link_to(label, href, **options) unless mulebox_external?(href)

    link_to(href, target: "_blank", rel: "noopener", **options) { safe_join([label, tag.span(" (opens in a new tab)", class: "visually-hidden")]) }
  end

  # "tel:+15551234567" from however the number is written.
  def mulebox_tel(phone = website_settings["phone"])
    digits = mulebox_plain(phone).gsub(/[^\d+]/, "")
    "tel:#{digits}" if digits.present?
  end

  def mulebox_year = Time.current.year

  # A global's data, or nil when the site doesn't have it (a fresh site, or
  # one whose content hasn't been copied yet), so the layout still draws.
  def mulebox_global(slug)
    website_global(slug)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # Whether the theme draws a collection's entries (website/entries/<slug>):
  # an entry of one it doesn't is a 404, so nothing links to it.
  def mulebox_draws?(collection_slug) = lookup_context.exists?("website/entries/#{collection_slug}", [], false)

  # ── Forms (the Forms plugin) ──

  # A published form by slug, or nil (no Forms plugin, or no such form).
  def mulebox_form(slug)
    return unless defined?(Form) && Cms::Plugins.enabled?(:forms)

    Form.find_by(slug: mulebox_plain(slug), status: "published")
  end

  # Where a form posts (the Forms plugin's public endpoint).
  def mulebox_form_action(form) = "/api/forms/#{form.slug}/submissions"

  # A choice field's options as the form defines them (a collection's
  # entries too, for one that lists them).
  def mulebox_choices(field) = defined?(FormChoices) ? FormChoices.for(field) : Array(field["options"]).select { it.is_a?(Hash) }

  # The spam check Settings › Forms has set up ({provider:, site_key:,
  # theme:}), or nil. The Forms plugin refuses a submission without its token
  # when one is, so a form that doesn't draw it never gets through.
  def mulebox_captcha = defined?(Forms) && Forms.respond_to?(:public_captcha) ? Forms.public_captcha : nil

  # A select for a choice field: a prompt, then the form's choices.
  def mulebox_select(field, id:, required:)
    prompt = tag.option(field["placeholder"].presence || "Choose…", value: "", disabled: required, selected: true)
    choices = mulebox_choices(field).map { tag.option(it["label"], value: it["value"]) }
    tag.select(safe_join([prompt, *choices]), id:, name: field["name"], required:)
  end

  # Where a form goes once it has sent: Site details' thank-you page for it
  # ("quote_thank_you", "franchise_thank_you"), or nil to thank in place.
  def mulebox_form_redirect(form)
    link = mulebox_site&.then { it.respond_to?(:"#{form.slug}_thank_you") ? it[:"#{form.slug}_thank_you"] : nil }
    mulebox_href(link) if link.present?
  end

  # Markdown as one inline run of HTML (no wrapping <p>), for a consent line
  # beside a checkbox.
  def mulebox_inline_markdown(text) = website_markdown(text).to_s.strip.delete_prefix("<p>").delete_suffix("</p>").html_safe # rubocop:disable Rails/OutputSafety -- website_markdown sanitized it

  # One of the quote form's text inputs (QuoteForm.svelte's): its label
  # read out but not shown, its label as the placeholder.
  def mulebox_quote_input(form, name, type: nil, data: nil, **options)
    field = website_form_field(form, name)
    id = "form-#{form.slug}-#{name}"
    tag.div(class: "form__field", data:) do
      safe_join([
        tag.label(field["label"], for: id, class: "visually-hidden"),
        tag.input(type: type || field["type"], id:, name: field["name"], required: field["required"].present?,
          placeholder: field["placeholder"].presence || field["label"], **options)
      ])
    end
  end

  # A field the form keeps for attribution: filled by the page, never shown.
  def mulebox_attribution?(field) = ATTRIBUTION.include?(field["name"])

  # The hidden attribution inputs, for the fields the form declares.
  def mulebox_attribution(form)
    safe_join(ATTRIBUTION.filter_map do |name|
      next unless form.fields.any? { it["name"] == name }

      tag.input(type: "hidden", name:, value: (name == "form_path") ? request.path : nil, data: {attribution: name})
    end)
  end

  private

  def mulebox_digest(file) = Digest::SHA1.file(file).hexdigest[0, 10]
end
