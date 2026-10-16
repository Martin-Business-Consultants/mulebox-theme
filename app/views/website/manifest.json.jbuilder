# frozen_string_literal: true

# The site as an app on a home screen (/site.webmanifest).
json.name mulebox_name
json.short_name mulebox_name.truncate(12, omission: "")
json.start_url "/"
json.display "standalone"
json.theme_color website_design(:accent)
json.background_color "#fbfcfb"
json.icons [{src: mulebox_favicon_href, sizes: "any", type: (mulebox_favicon_href.include?(".svg") ? "image/svg+xml" : "image/png")}]
