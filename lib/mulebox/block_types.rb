# frozen_string_literal: true

module Mulebox
  # The block types this theme adds to the core's (BlockType::Defaults in the
  # CMS), as the same hashes. The CMS installs them the first time the theme
  # is switched on (Cms::Plugins.block_types) and leaves them alone after, so
  # an editor's changes to one stay; script/import.rb brings them up to date.
  # Each has a partial in app/views/website/blocks. A list is a string_list
  # or a repeater, never a string: a string field turns an empty list into "".
  #
  # The Mule Box sections are the Astro site's components
  # (src/components/*.astro), each with the fields it read from Directus, and
  # the copy it wrote in (the comparison's rows, the hourly movers, the
  # what-fits chart) as fields too, so an editor can change it.
  module Fields
    module_function

    def f(name, type = "string", label = nil, **opts)
      {"name" => name, "label" => label || name.to_s.humanize, "type" => type}.merge(opts.transform_keys(&:to_s))
    end

    def repeater(name, of, label = nil, **opts) = f(name, "repeater", label, of:, **opts)

    def select(name, options, label = nil, **opts) = f(name, "select", label, options:, **opts)
  end

  extend Fields

  MARKETS = %w[dallas-fort-worth austin bayarea bossier-city].freeze
  BUTTON = [f("label", "string", "Label", required: true), f("link", "link", "Link", required: true)].freeze

  BLOCK_TYPES = [
    {
      slug: "form", label: "Form", category: "Forms", icon: "ClipboardList",
      description: "One of the site's forms (Forms), with a heading and an intro. Answers go to Submissions.",
      fields: [
        {"name" => "form", "label" => "Form", "type" => "string", "required" => true,
         "help" => "The form's slug, as Forms lists it (e.g. \"quote\")."},
        {"name" => "heading", "label" => "Heading", "type" => "string"},
        {"name" => "body", "label" => "Intro", "type" => "text"}
      ],
      defaults: {"form" => "quote", "heading" => "Get in touch"}
    },
    {
      slug: "faq", label: "FAQ", category: "Content", icon: "CircleHelp",
      description: "Questions and answers, each opening in place. Search engines get them as an FAQ.",
      fields: [
        {"name" => "heading", "label" => "Heading", "type" => "string"},
        {"name" => "body", "label" => "Intro", "type" => "text"},
        {"name" => "items", "label" => "Questions", "type" => "repeater", "required" => true,
         "of" => [
           {"name" => "question", "label" => "Question", "type" => "string", "required" => true},
           {"name" => "answer", "label" => "Answer", "type" => "markdown", "required" => true}
         ]}
      ],
      defaults: {
        "items" => [
          {"question" => "Does Mule Box serve my area?", "answer" => "Mule Box is growing fast. [Click here](/locations) to see if we're in your market."},
          {"question" => "How much can I fit in a Mule Box?", "answer" => "We offer 16′ x 8′ x 8′ boxes, and 20′ x 8′ x 8′ in some markets."}
        ]
      }
    },
    {
      slug: "mule_hero", label: "Hero with quote form", category: "Mule Box", icon: "LayoutTemplate",
      description: "The full-height photo hero: a heading, a line, two buttons, and the quote form (or the franchise form) beside them. " \
                   "Give it several slides and they fade from one to the next, as on the home page.",
      fields: [
        f("bg_image", "asset", "Background photo"),
        f("slides", "repeater", "Slides", of: [f("image", "asset", "Photo", required: true)],
          help: "Photos that take turns behind the hero (the home page's). Leave empty for the one background photo."),
        f("badge", "string", "Badge", help: "A yellow badge above the heading, e.g. \"20' Boxes Now Available!\""),
        f("title", "string", "Heading", required: true),
        f("subtitle", "text", "Line under the heading"),
        repeater("buttons", BUTTON, "Buttons", help: "The first is teal, the rest white. Shown on tablets and up."),
        select("form", %w[quote franchise none], "Form beside it", required: true),
        f("quote_title", "text", "Quote form heading", help: "One line each, e.g. \"Instant Quote\" and \"$99 + $1 Delivery\"."),
        f("consent", "markdown", "SMS consent", help: "Beside the quote form's checkbox. Blank: Site details › SMS consent."),
        f("franchise_title", "string", "Franchise form heading")
      ],
      defaults: {"title" => "The Locally-Owned, Low-Priced Portable Storage Company!", "subtitle" => "5-Star Reviews • Fast Delivery • Straight-Forward Pricing",
                 "buttons" => [{"label" => "Fast Quote", "link" => {"kind" => "page", "value" => "quote"}}], "form" => "quote", "quote_title" => "Instant Quote\nLow Rates Await"}
    },
    {
      slug: "single_hero", label: "Photo banner", category: "Mule Box", icon: "Image",
      description: "A photo banner with a heading and a line under it (the About page's).",
      fields: [f("bg_image", "asset", "Background photo"), f("title", "string", "Heading", required: true), f("description", "text", "Line under it")],
      defaults: {"title" => "Your Local Portable Container Provider", "description" => "Learn what's behind The Mule."}
    },
    {
      slug: "how_it_works", label: "How it works", category: "Mule Box", icon: "ListOrdered",
      description: "Numbered steps, each with an icon, joined by a dashed line, and a button under them if you like.",
      fields: [
        f("title", "string", "Heading"), f("description", "text", "Intro"),
        repeater("steps", [f("title", "string", "Step", required: true), f("image", "asset", "Icon"), f("description", "text", "Text")], "Steps", required: true),
        f("button_label", "string", "Button label"), f("button_link", "link", "Button link")
      ],
      defaults: {"title" => "How It Works", "steps" => [{"title" => "Order Your Mule Box"}, {"title" => "Mule Box Arrives"}, {"title" => "Pack the Mule Box"}, {"title" => "Keep It, Move It or Store It"}]}
    },
    {
      slug: "title_description", label: "Heading and text", category: "Mule Box", icon: "Heading",
      description: "A centered heading, the red rule under it, and a paragraph, on white or the brand red.",
      fields: [f("title", "string", "Heading", required: true), f("description", "text", "Text"), f("red_background", "boolean", "On the brand red")],
      defaults: {"title" => "A Storage Box That Fits All Your Needs", "red_background" => true}
    },
    {
      slug: "service_areas", label: "Service areas", category: "Mule Box", icon: "MapPin",
      description: "The towns a market serves, in columns on grey.",
      fields: [f("title", "string", "Heading", required: true), f("description", "text", "Intro"), f("areas", "string_list", "Towns")],
      defaults: {"title" => "Servicing the Bay Area and Beyond", "areas" => %w[Antioch Atherton Belmont]}
    },
    {
      slug: "two_col", label: "Photo and text", category: "Mule Box", icon: "Columns2",
      description: "A photo beside a heading, text and a button, on white or the brand red.",
      fields: [
        f("image", "asset", "Photo"), f("title", "string", "Heading", required: true), f("description", "markdown", "Text"),
        f("button_label", "string", "Button label"), f("button_link", "link", "Button link"),
        f("image_on_left", "boolean", "Photo on the left"), f("red_background", "boolean", "On the brand red")
      ],
      defaults: {"title" => "16' & 20' Mule Boxes", "description" => "16' x 8' - holds up to a 2BR worth of contents", "image_on_left" => true}
    },
    {
      slug: "comparison", label: "Comparison table", category: "Mule Box", icon: "Table",
      description: "Mule Box against PODS® and 1-800-PACK-RAT®, feature by feature.",
      fields: [
        f("header", "string", "Heading"), f("subheader", "string", "Line under it"),
        repeater("rows", [f("feature", "string", "Feature", required: true), f("mulebox", "boolean", "Mule Box"),
          f("pods", "boolean", "PODS®"), f("packrat", "boolean", "1-800-PACK-RAT®")], "Rows")
      ],
      defaults: {"header" => "Nobody Keeps Pace With The Mule", "subheader" => "Mule Box Advantages",
                 "rows" => [{"feature" => "EASY-OPEN SWING DOORS", "mulebox" => true, "pods" => false, "packrat" => false}]}
    },
    {
      slug: "team", label: "Team", category: "Mule Box", icon: "Users",
      description: "The team, two to a row, on the dark band.",
      fields: [f("title", "string", "Heading", required: true),
        repeater("members", [f("image", "asset", "Photo"), f("name", "string", "Name", required: true), f("role", "string", "Role"), f("bio", "text", "Bio")], "People")],
      defaults: {"title" => "Meet the Mule Team", "members" => [{"name" => "Steve Choppin", "role" => "Founder/Co-Chief Mule Officer"}]}
    },
    {
      slug: "pricing_factors", label: "Pricing factors", category: "Mule Box", icon: "LayoutGrid",
      description: "Four pictures, each over what it says.",
      fields: [f("title", "string", "Heading", required: true),
        repeater("factors", [f("image", "asset", "Picture"), f("description", "string", "Text", required: true)], "Factors")],
      defaults: {"title" => "Factors That Affect Commercial Storage Container Costs", "factors" => [{"description" => "Delivery date selection"}]}
    },
    {
      slug: "rich_text", label: "Rich text", category: "Mule Box", icon: "AlignLeft",
      description: "Text, with headings, lists, links and pictures.",
      fields: [f("content", "markdown", "Text", required: true), f("centered", "boolean", "Centered")],
      defaults: {"content" => "### Contact Us\n\nWe're usually out delivering Mule Boxes, so if you have any questions, give us a call."}
    },
    {
      slug: "hourly_movers", label: "Hourly movers", category: "Mule Box", icon: "Truck",
      description: "The movers customers recommend, their rates, and the note that Mule Box doesn't endorse them.",
      fields: [
        f("title", "string", "Heading", required: true), f("image", "asset", "Picture"),
        repeater("movers", [f("name", "string", "Mover", required: true), f("url", "string", "Website"), f("phone", "string", "Phone"), f("rate", "string", "Rate")], "Movers"),
        f("footnote", "string", "Under the table"), f("note_heading", "string", "Note heading"), f("note", "text", "Note")
      ],
      defaults: {"title" => "Need an Extra Hand?", "movers" => [{"name" => "PiggyBack Moving", "phone" => "817.380.5665", "rate" => "$115/hr (2.5 hr min)"}],
                 "note_heading" => "PLEASE NOTE:"}
    },
    {
      slug: "what_fits_table", label: "What fits chart", category: "Mule Box", icon: "Table",
      description: "How many boxes a home needs, by its size and how furnished it is.",
      fields: [f("columns", "string_list", "Column headings"),
        repeater("rows", [f("size", "string", "Home size", required: true), f("light", "string", "Lightly furnished"),
          f("moderate", "string", "Moderately furnished"), f("heavy", "string", "Heavily furnished")], "Rows")],
      defaults: {"columns" => ["Home Size / Sq ft", "Lightly Furnished", "Moderately Furnished", "Heavily Furnished"],
                 "rows" => [{"size" => "400 to 1,000 sq ft", "light" => "1x - 16’ x 8’ box", "moderate" => "1x - 16’ x 8’ box", "heavy" => "1x - 16’ x 8’ box"}]}
    },
    {
      slug: "quote_section", label: "Quote form", category: "Mule Box", icon: "ClipboardList",
      description: "The quote form on its own, in the thick red frame (the Get a Quote page's).",
      fields: [f("title", "string", "Heading", required: true), f("consent", "markdown", "SMS consent", help: "Blank: Site details › SMS consent.")],
      defaults: {"title" => "Save BIG & Get Your Instant Quote Savings Now"}
    },
    {
      slug: "recent_posts", label: "Recent posts", category: "Mule Box", icon: "Newspaper",
      description: "The blog's posts, newest first, as cards.",
      fields: [f("title", "string", "Heading")],
      defaults: {"title" => "Recent Posts"}
    },
    {
      slug: "locations_list", label: "Locations", category: "Mule Box", icon: "MapPin",
      description: "Every location (the Locations collection), as cards with their photos.",
      fields: [f("title", "string", "Heading", required: true), f("description", "string", "Line under it")],
      defaults: {"title" => "Mule Box Locations", "description" => "Discover our various Mule Box locations near you!"}
    },
    {
      slug: "thank_you", label: "Thank-you banner", category: "Mule Box", icon: "PartyPopper",
      description: "A photo band that thanks the visitor (after a quote request or the franchise form).",
      fields: [f("bg_image", "asset", "Background photo", help: "Blank: the theme's packed-boxes photo."), f("title", "string", "Heading", required: true), f("message", "text", "Message")],
      defaults: {"title" => "Thank you for your interest in Mule Box!", "message" => "We will be in touch very soon."}
    }
  ].freeze
end
