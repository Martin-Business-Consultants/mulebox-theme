# frozen_string_literal: true

module Mulebox
  # A theme is an engine like a plugin: its views and helpers join the app's,
  # and it registers with Website, which turns the public site on. Its files
  # are served by the theme itself (Mulebox::AssetsController), so it works
  # however it was installed; its scripts get an importmap of their own
  # (the theme helper's mulebox_javascript_tags), so the admin's never reach a
  # visitor.
  class Engine < ::Rails::Engine
    # The theme's files, ahead of the website's catch-all.
    initializer "mulebox.routes" do |app|
      app.routes.append do
        get "_mulebox/*path", to: "mulebox/assets#show", format: false, as: :mulebox_asset
      end
    end

    config.to_prepare do
      # A plugin too, so Settings › Plugins installs it from its GitHub
      # release, updates it, and switches the site on and off.
      Cms::Plugins.register :mulebox, name: "Mule Box", version: Mulebox::VERSION,
        description: "mulebox.com, drawn from the CMS's content: switch it off and the CMS is headless.",
        author: "Martin Business Consultants", enabled_by_default: true, requires: ">= 1.33",
        homepage: "https://github.com/Martin-Business-Consultants/#{"mulebox".tr("_", "-")}-theme"
      # Block types the theme draws beyond the core's, installed the first
      # time it's switched on (an existing block type is left as it is).
      Cms::Plugins.block_types :mulebox, Mulebox::BLOCK_TYPES
      Website.register :mulebox, name: "Mule Box", version: Mulebox::VERSION,
        views: Mulebox::Engine.root.join("app/views"),
        # What an editor can change in Settings › Themes › Customize; the
        # stylesheet reads them as --design-accent and the rest.
        design: [
          {name: "accent", label: "Brand red (top bar, bands, headings)", type: "color", default: "#852d33"},
          {name: "secondary", label: "Button teal", type: "color", default: "#2d857f"},
          {name: "ink", label: "Text color", type: "color", default: "#101920"},
          {name: "heading_font", label: "Headings", type: "select", default: "slab",
           options: {"slab" => "'Roboto Slab', Georgia, serif", "sans" => "'Open Sans', ui-sans-serif, system-ui, sans-serif"}},
          {name: "radius", label: "Corners", type: "select", default: "soft",
           options: {"square" => "0", "soft" => "4px", "round" => "12px"}},
          {name: "cookie_banner", label: "Ask visitors about cookies", type: "boolean", default: true}
        ]
    end
  end
end
