# frozen_string_literal: true

# mulebox.com's content, into this CMS: block types, collections, pages,
# locations, posts, globals, forms, settings and redirects. Run inside a Libre
# Publish checkout with the theme linked, as often as you like (everything is
# matched by slug, path or file name and updated):
#
#   bin/rails runner themes/mulebox/script/import.rb
#
# The Astro site (Brem-LLC/mulebox) drew every page, location, post, the
# header and the footer from a Directus CMS at request time, and its
# components wrote the rest in. What the deployed site showed is in the repo:
#
#   script/data/live.json         every page's and location's sections as block data, the posts,
#                                 the header and footer (script/scrape-live, from mulebox.com)
#   script/data/media.json, media/ every image those use, each picture once (script/fetch-media)
#
# The copy the components wrote in (the comparison's rows, the hourly movers,
# the what-fits chart, the quote card's small print, the cookie notice) is in
# the blocks' and globals' fields, so an editor can change it.
require_relative "import/kit"
require "json"

module Mulebox
  module Import
    ROOT = Pathname(File.realpath(__dir__))
    LIVE = JSON.parse(ROOT.join("data/live.json").read)
    MEDIA_MAP = JSON.parse(ROOT.join("data/media.json").read)
    MEDIA = ROOT.join("media")
    FOLDER = "/mulebox"
    SCRAPED_ALT = LIVE["media"].to_h { [it["file"], it["alt"]] }

    extend Mulebox::Fields

    module_function

    # ── Media ────────────────────────────────────────────────────────────────

    # An image the scrape named, as an asset id: one asset per picture,
    # matched by its file name, so a second run reuses it. Its alt text is
    # what the site gave it, else what it shows in `context`.
    def asset(scraped, context: nil)
      return if scraped.blank?

      stored = MEDIA_MAP.fetch(scraped) { raise "no file for #{scraped} in data/media.json" }
      filename = stored["file"]
      (@assets ||= {})[filename] ||= begin
        alt = alt_for(scraped, stored["title"], context)
        record = Asset.where(folder: FOLDER).joins(file_attachment: :blob).find_by(active_storage_blobs: {filename:})
        if record
          record.update!(alt:) if record.alt.blank?
        else
          record = Asset.create!(file: {io: MEDIA.join(filename).open("rb"), filename:}, folder: FOLDER, alt:,
            name: File.basename(filename, ".*").sub(/\A\h{8}-/, "").tr("-_", "  ").squish.capitalize)
        end
        record.id.to_s
      end
    end

    # A placeholder name ("image-3", "Frame 2147239", a camera's) says nothing.
    def alt_for(scraped, title, context)
      useful = ->(text) { text.present? && !text.match?(/\A(image|img|frame|dsc|screenshot|untitled|copy of)[\s_-]*\d*/i) && !text.match?(/\A[\w-]*\d{4,}/) }
      [SCRAPED_ALT[scraped], context, title].map { it.to_s.squish }.find { useful.(it) } || "Mule Box portable storage container"
    end

    # Markdown's pictures ("media:<name>") as the CMS's own address for them.
    def markdown(text, context: nil)
      local_links(text.to_s.gsub(/\(media:([^)\s]+)\)/) { "(#{Asset.find(asset($1, context:)).url})" })
    end

    # ── Links ────────────────────────────────────────────────────────────────

    # An address as a link field: a page by its path, an entry at its own,
    # or the URL as written ("/#how-it-works", another site).
    def href_link(href)
      href = href.to_s.sub(%r{\Ahttps?://(www\.)?mulebox\.com}, "")
      return {"kind" => "url", "value" => href} unless href.start_with?("/") && !href.include?("#")

      bare = href.delete_prefix("/").delete_suffix("/")
      return {"kind" => "page", "value" => "home"} if bare.empty?

      collection, slug, *rest = bare.split("/")
      if rest.empty? && slug && Collection.find_by(slug: collection)&.entries&.exists?(slug:)
        {"kind" => "entry", "collection" => collection, "value" => slug}
      elsif Page.exists?(path: bare)
        {"kind" => "page", "value" => bare}
      else
        {"kind" => "url", "value" => "/#{bare}"}
      end
    end

    # Markdown links to this site, relative (Directus held some as
    # https://mulebox.com/…), so they work wherever the site is served.
    def local_links(markdown) = markdown.to_s.gsub(%r{\]\(https?://(?:www\.)?mulebox\.com(/[^)]*)?\)}) { "](#{$1.presence&.delete_suffix("/").presence || "/"})" }

    # ── Content ──────────────────────────────────────────────────────────────

    # A scraped section as its block: its images as assets, its links as
    # link fields, its Markdown with the CMS's addresses.
    def convert(raw, opener:)
      type = raw["type"]
      data = raw["data"].deep_dup
      heading = data["title"] || data["header"]
      case type
      when "mule_hero"
        data["bg_image"] = asset(data["bg_image"], context: heading)
        data["slides"] = data["slides"].map { {"image" => asset(it)} }
        data["buttons"] = data["buttons"].map { {"label" => it["label"], "link" => href_link(it["link"])} }
        data["consent"] = local_links(data["consent"])
      when "single_hero", "thank_you"
        data["bg_image"] = asset(data["bg_image"], context: heading)
      when "how_it_works"
        data["steps"] = data["steps"].map { it.merge("image" => asset(it["image"], context: it["title"])) }
        data["button_link"] = href_link(data["button_link"]) if data["button_link"].present?
      when "two_col"
        data["image"] = asset(data["image"], context: heading)
        data["description"] = markdown(data["description"], context: heading)
        data["button_link"] = href_link(data["button_link"]) if data["button_link"].present?
      when "team"
        data["members"] = data["members"].map { it.merge("image" => asset(it["image"], context: it["name"])) }
      when "pricing_factors"
        data["factors"] = data["factors"].map { it.merge("image" => asset(it["image"], context: it["description"])) }
      when "hourly_movers"
        data["image"] = asset(data["image"], context: heading)
      when "faq"
        data["items"] = data["items"].map { it.merge("answer" => local_links(it["answer"])) }
      when "rich_text"
        # The page's h1 is its opening section's: a heading the text opens
        # with moves down one.
        content = markdown(data["content"], context: "Mule Box")
        data["content"] = opener ? content.gsub(/^# /, "## ") : content
      when "quote_section"
        data["consent"] = local_links(data["consent"])
      end
      block(type, data)
    end

    def blocks_for(raw)
      opener = raw.first && Mulebox::Import::OPENERS.include?(raw.first["type"])
      raw.map { convert(it, opener:) }
    end

    OPENERS = %w[mule_hero single_hero quote_section thank_you locations_list hourly_movers recent_posts].freeze

    # The SEO the deployed page had: its <title> and description as written.
    def seo(live)
      live = live.to_h
      {"meta_title" => live["meta_title"].presence, "meta_description" => live["meta_description"].presence}.compact
    end

    # ── Records ──────────────────────────────────────────────────────────────

    def settings
      puts "== settings"
      site = LIVE["site"]
      Setting.set("general", Setting.get("general").to_h.merge("title" => site["title"], "description" => site["description"]))
      favicon = Asset.where(folder: FOLDER).joins(file_attachment: :blob).find_by(active_storage_blobs: {filename: "mulebox-favicon.png"}) ||
        Asset.create!(file: {io: Mulebox::Engine.root.join("app/assets/images/mulebox/favicon.png").open("rb"), filename: "mulebox-favicon.png"},
          folder: FOLDER, alt: "Mule Box", name: "Mule Box favicon")
      Setting.set("branding", Setting.get("branding").to_h.merge("logo_id" => asset(site["logo"], context: "Mule Box"), "favicon_id" => favicon.id.to_s))
    end

    def block_types
      puts "== block types"
      # The theme's own (lib/mulebox/block_types.rb), as they are now:
      # installed once when the theme is switched on, so brought up to date here.
      Mulebox::BLOCK_TYPES.each do |type|
        BlockType.find_or_initialize_by(slug: type[:slug]).update!(type.except(:slug).merge(version: 1, deprecated: false))
      end
    end

    def collections
      puts "== collections"
      @blog = Collection.find_or_initialize_by(slug: "blog")
      @blog.update!(name: "Blog", icon: "Newspaper", enable_blocks: false, schema: {"fields" => [
        f("image", "asset", "Picture"),
        f("description", "text", "Summary", help: "The post's description for search. Blank: \"Mule Box blog post - <title>\".")
      ]})
      @locations = Collection.find_or_initialize_by(slug: "locations")
      @locations.update!(name: "Locations", icon: "MapPin", enable_blocks: true, schema: {"fields" => [
        f("phone", "string", "Phone", help: "In the top bar on this location's page."),
        select("market", Mulebox::MARKETS, "Market", help: "Quote requests from this page are filed under it."),
        f("featured_image", "asset", "Photo", help: "On the Locations page. A location without one isn't listed there."),
        f("order", "integer", "Order", help: "Where it comes on the Locations page.")
      ]})
    end

    def pages
      puts "== pages"
      LIVE["pages"].each do |live|
        draft = live["path"] == "lilypad-full-width"
        page(live["path"], title: live["heading"] || live["title"], blocks: blocks_for(live["blocks"]), seo: seo(live["seo"]),
          status: draft ? "draft" : "published").tap do |record|
          record.update!(published_at: Time.current) if record.published_at.nil? && !draft
        end
      end
      # The quote results page priced quotes live from gofuse; a quote request
      # comes here now (Site details › After a quote request).
      page("quote-thank-you", title: "Thank You!", seo: {"meta_title" => "Thank You! - Mule Box", "meta_description" => "Thank you page after quote submission."},
        blocks: [block("thank_you", {"bg_image" => nil, "title" => "Thank you for your interest in Mule Box!", "message" => "We will be in touch very soon."})])
        .tap { it.update!(published_at: Time.current) if it.published_at.nil? }
    end

    def locations
      puts "== locations"
      types = BlockType.all.index_by(&:slug)
      LIVE["locations"].each do |live|
        blocks = blocks_for(live["blocks"]).map { it.merge("data" => conform(it["data"], types[it["type"]]&.fields)) }
        frontmatter = live["frontmatter"].merge("featured_image" => asset(live["frontmatter"]["featured_image"], context: "Mule Box in #{live["title"]}"),
          "order" => live["order"])
        entry = @locations.entries.find_or_initialize_by(slug: live["slug"])
        status = blocks.empty? ? "draft" : "published"
        entry.update!(title: live["title"], status:, locale: "en", seo: seo(live["seo"]), blocks:, frontmatter: conform(frontmatter, @locations.fields),
          published_at: entry.published_at || (Time.current if status == "published"))
      end
    end

    def posts
      puts "== posts"
      LIVE["posts"].each do |live|
        meta = live["seo"]["meta_description"].to_s
        description = meta.start_with?("Mule Box blog post - ") ? "" : meta
        entry = @blog.entries.find_or_initialize_by(slug: live["slug"])
        entry.update!(title: live["title"], status: "published", locale: "en", seo: seo(live["seo"]).except("meta_description"),
          frontmatter: conform({"image" => asset(live["frontmatter"]["image"], context: live["title"]), "description" => description}, @blog.fields),
          body_markdown: markdown(live["body_markdown"], context: live["title"]),
          published_at: Time.zone.parse("#{live["published_on"].presence || live["listed_on"]} 12:00"))
        # The blog lists posts newest-created first, as Directus held them.
        entry.update_columns(created_at: Time.zone.parse(live["created_at"]))
      end
    end

    def globals
      puts "== globals"
      g = LIVE["globals"]
      site = LIVE["site"]
      link_item = [f("label", "string", "Label", required: true), f("link", "link", "Link", required: true)]

      global_record "nav", name: "Navigation", icon: "Menu", description: "The header's menu: an item with links under it opens them in place.",
        fields: [repeater("items", [f("label", "string", "Label", required: true),
          f("link", "link", "Link", help: "Blank for an item that only opens the links under it."),
          repeater("children", link_item, "Links under it")], "Items", required: true)],
        data: {"items" => g["nav"].map do |item|
          {"label" => item["label"], "link" => (href_link(item["link"]) if item["link"].present?),
           "children" => item["children"].map { {"label" => it["label"], "link" => href_link(it["link"])} }}.compact
        end}

      footer = g["footer"]
      global_record "footer", name: "Footer", icon: "PanelBottom", description: "The logo and disclaimer, the link columns, and the copyright and legal links.",
        fields: [
          f("logo", "asset", "Logo", help: "Blank: the theme's."), f("disclaimer", "text", "Disclaimer"),
          repeater("columns", [f("heading", "string", "Heading"), repeater("items", link_item, "Links")], "Columns"),
          f("social_heading", "string", "Social links heading", help: "The links are Site details › Social links."),
          f("copyright", "string", "Copyright text", help: "{year} is this year."),
          repeater("legal", link_item, "Legal links")
        ],
        data: {
          "logo" => asset(site["footer_logo"], context: "Mule Box"), "disclaimer" => footer["disclaimer"],
          "columns" => footer["columns"].map { |column| {"heading" => column["heading"], "items" => column["items"].map { {"label" => it["label"], "link" => href_link(it["link"])} }} },
          "social_heading" => footer["social_heading"], "copyright" => footer["copyright"],
          "legal" => footer["legal"].map { {"label" => it["label"], "link" => href_link(it["link"])} }
        }

      global_record "site", name: "Site details", icon: "Store",
        description: "The top bar, the social links, the quote button, and the copy every quote form shares.",
        fields: [
          f("topbar_text", "string", "Top bar line"),
          repeater("social", [f("network", "string", "Network", required: true, help: "Facebook, Instagram, YouTube, LinkedIn or Pinterest."), f("url", "string", "Address", required: true)], "Social links"),
          f("quote_label", "string", "Quote button label"), f("quote_link", "link", "Quote button link"),
          f("quote_thank_you", "link", "After a quote request, go to", help: "Blank: the form says thanks in place."),
          f("franchise_thank_you", "link", "After the franchise form, go to", help: "Blank: the form says thanks in place."),
          f("details_note", "string", "Under a quote form's heading"),
          f("offer_note", "text", "Under a quote form", help: "The offer's small print."),
          f("consent", "markdown", "SMS consent", help: "Beside the quote form's checkbox, where a hero doesn't have its own."),
          f("cookie_notice", "markdown", "Cookie notice", help: "The cookie banner's text (Settings › Themes › Customize turns the banner off).")
        ],
        data: {
          "topbar_text" => site["topbar_text"], "social" => site["social"],
          "quote_label" => site["quote_label"], "quote_link" => href_link(site["quote_link"]),
          "quote_thank_you" => {"kind" => "page", "value" => "quote-thank-you"},
          "franchise_thank_you" => {"kind" => "page", "value" => "thank-you-franchise"},
          "details_note" => "(Details Apply)",
          "offer_note" => "*Offer available for new orders only on the container rental only (does not apply to transportation or storage at our facilities)",
          "consent" => LIVE["pages"].find { it["path"] == "quote" }["blocks"].first["data"]["consent"].then { local_links(it) },
          "cookie_notice" => "We use essential cookies to operate this site and, with your consent, non-essential cookies for analytics. " \
                             "See our [Privacy Policy](/privacy-policy) and [Terms of Service](/terms-of-service)."
        }

      scripts
    end

    def global_record(slug, name:, fields:, data:, description:, icon: "Settings")
      Global.find_or_initialize_by(slug:).tap { it.update!(name:, description:, icon:, schema: {"fields" => fields}, data: conform(data, fields)) }
    end

    # The tag every page of the deployed site loaded (Layout.astro): Google Tag Manager.
    def scripts
      gtm = "GTM-N5VBB7T"
      items = [{"name" => "Google Tag Manager",
                "head" => %(<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','#{gtm}');</script>),
                "body" => %(<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=#{gtm}" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>)}]
      record = Global.find_by!(slug: "scripts")
      record.update!(data: record.data.to_h.merge("items" => items))
    end

    # ── Forms ────────────────────────────────────────────────────────────────

    # Who the Astro site's actions mailed (src/config/form.ts): every market's
    # new-lead notice, and the franchise inquiries.
    QUOTE_TO = "steve@mulebox.com, matt@mulebox.com"
    FRANCHISE_TO = "steve@mulebox.com"
    ATTRIBUTION = %w[utm_source utm_medium utm_campaign gclid landing_path].freeze

    def forms
      puts "== forms"
      field = ->(name, label, type = "text", required: false, **opts) { {"name" => name, "label" => label, "type" => type, "required" => required}.merge(opts.transform_keys(&:to_s)) }
      options = ->(pairs) { pairs.map { |value, label| {"value" => value, "label" => label} } }
      attribution = ATTRIBUTION.map { field.(it, it.humanize) }
      markets = {"dallas-fort-worth" => "Dallas / Fort Worth", "austin" => "Austin", "bayarea" => "Bay Area", "bossier-city" => "Bossier City"}

      definitions = {
        # QuoteForm.svelte (src/config/form.ts's FIELDS)
        "quote" => {title: "Get a quote", submit: "Get Your Quote", success: "Thank you for your interest in Mule Box! We will be in touch very soon.",
                    subject: "New Mule Box quote request — {{first_name}} {{last_name}}", to: QUOTE_TO,
                    reply: ["Thanks for your Mule Box quote request", "Thank you, {{first_name}}!",
                      "<p>We have your quote request and a Mule Box team member will be in touch very soon with your pricing.</p>"],
                    fields: [
                      field.("service_type", "Service Type", "radio", required: true, options: options.([%w[keep_it Keep\ It], %w[move_it Move\ It], %w[store_it Store\ It]])),
                      field.("first_name", "First Name", required: true), field.("last_name", "Last Name", required: true),
                      field.("delivery_zip", "Delivery Zip Code", required: true),
                      field.("relocation_zip", "Relocation Zip Code", help: "For Move It: where the box goes."),
                      field.("container_size", "Container size", "select", placeholder: "Select Container Type", options: options.([["16x8", "16' x 8'"], ["20x8", "20' x 8' (in some markets)"]])),
                      field.("delivery_date", "Delivery date", placeholder: "MM/DD/YYYY"),
                      field.("email", "Email Address", "email", required: true), field.("phone", "Phone Number", "tel", required: true),
                      field.("storage_type", "Storage", "radio", help: "For Store It.", options: options.([%w[indoor Indoor], %w[outdoor Outdoor]])),
                      field.("sms_consent", "I agree to receive SMS messages from Mule Box", "checkbox"),
                      field.("market", "Market", "select", help: "Set by a location's page.", options: options.(markets.to_a)),
                      *attribution
                    ]},
        # Forms/FranchiseForm.astro
        "franchise" => {title: "I'd Like to Know More About The Mule", submit: "Submit Form", success: "Thank you for your interest in Mule Box!",
                        subject: "New Lead: Mule Box Franchisee Inquiry", to: FRANCHISE_TO,
                        reply: ["Mule Box Franchisee Inquiry", "Thanks for your interest in Mule Box.",
                          "<p>We have your inquiry and will be in touch shortly.</p>"],
                        fields: [
                          field.("name", "Name", required: true), field.("email", "Email", "email", required: true),
                          field.("phone_number", "Phone Number", "tel", required: true), field.("market_interest", "Market of Interest", required: true),
                          field.("has_assets", "Do you have assets over $1 million USD?", "radio", options: options.([%w[yes Yes], %w[no No]])),
                          *attribution
                        ]}
      }
      definitions.each do |slug, d|
        form = Form.find_or_initialize_by(slug:)
        form.update!(title: d[:title], status: "published", submit_label: d[:submit], success_message: d[:success], fields: d[:fields])
        form.notification_email&.update!(enabled: true, recipients: d[:to], subject: d[:subject])
        subject, heading, body = d[:reply]
        form.confirmation_email&.update!(enabled: true, subject:, blocks: [
          FormEmail::BlockTypes.build("email_heading").merge("data" => {"text" => heading, "level" => "h1", "align" => "left"}),
          FormEmail::BlockTypes.build("email_text").merge("data" => {"body" => body}),
          FormEmail::BlockTypes.build("email_submission").merge("data" => {"title" => "Your request", "skip_empty" => true})
        ])
      end
    end

    # Addresses the Astro site answered that have no page of their own here.
    def redirects
      puts "== redirects"
      {
        "/thank-you" => "/quote-thank-you",
        "/quote-thank-you/austin" => "/quote-thank-you", "/quote-thank-you/bayarea" => "/quote-thank-you",
        "/quote-thank-you/bossier-city" => "/quote-thank-you", "/quote-thank-you/dallas-fort-worth" => "/quote-thank-you"
      }.each do |from, to|
        Redirect.find_or_initialize_by(source_path: from).update!(destination_url: to, status_code: 301, active: true)
      end
    end

    def run
      settings
      block_types
      collections
      pages
      locations
      posts
      pages # again, now the locations and posts are in, so links to them are entry links
      globals
      forms
      redirects
      # The fresh site's sample home page is replaced by mulebox.com's.
      puts "Imported: #{Page.count} pages, #{CollectionEntry.count} entries, #{Asset.where(folder: FOLDER).count} images, #{Form.count} forms."
    end
  end
end

ActiveRecord::Base.transaction { Mulebox::Import.run }
