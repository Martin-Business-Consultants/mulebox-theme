# frozen_string_literal: true

require "rails_helper"
require_relative "../support/mulebox_content"

# mulebox.com's own pieces, against its content (the snapshot): the lists in
# the order the Astro site showed them, its sections' content, the quote form
# a location files under its market, the redirects, and the design settings.
RSpec.describe "Mule Box", type: :request, website: true do
  before do
    skip "needs the site's snapshot (bin/rails mulebox:snapshot)" unless Mulebox::Content.snapshot?

    switch_plugin :forms, on: true if Cms::Plugins.manifests.key?(:forms)
    Website.themes.each_key { |key| switch_plugin key.to_sym, on: key == "mulebox" if Cms::Plugins.manifests.key?(key.to_sym) }
    Mulebox::Content.load!
    images!
  end

  PIXEL = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==".unpack1("m")

  # The snapshot names its images by asset id; a pixel stands in for each.
  def images!
    ids = Mulebox::Content::SNAPSHOT.to_json.scan(/"(?:image|bg_image|featured_image|logo)":"?(\d+)/).flatten.map(&:to_i).uniq
    ids.each { Asset.create!(id: it, file: {io: StringIO.new(PIXEL), filename: "pixel-#{it}.png"}, alt: "A picture") unless Asset.exists?(it) }
  end

  def html = Nokogiri::HTML5(response.body)

  it "opens the home page with its hero, the quote form beside it, and its slides" do
    get "/"

    hero = html.at_css(".mule-hero")
    expect(hero.at_css("h1").text).to eq("The Locally-Owned, Low-Priced Portable Storage Company!")
    expect(hero.css(".mule-hero__slide").size).to eq(6)
    expect(hero.at_css("form[data-form=quote]")).to be_present
    expect(html.css("#how-it-works .steps__item h3").map(&:text)).to eq(["Order Your Mule Box", "Mule Box Arrives", "Pack the Mule Box", "Keep It, Move It or Store It"])
  end

  it "lists the locations in the Astro site's order, each with its photo, and none without one" do
    get "/locations"

    expect(html.css(".location-card h2").map(&:text)).to eq(["Austin", "Bay Area", "Bossier City", "Dallas/Fort Worth"])
    expect(html.css(".location-card img").size).to eq(4)
  end

  it "shows a location's phone in the top bar and files its quote form under its market" do
    get "/locations/austin"

    expect(html.at_css(".topbar__phone")["href"]).to eq("tel:5125752929")
    expect(html.at_css("form[data-form=quote] input[name=market]")["value"]).to eq("austin")

    get "/"
    expect(html.at_css(".topbar__phone")).to be_nil
    expect(html.at_css("form[data-form=quote] input[name=market]")["value"]).to be_blank
  end

  it "lists the blog newest first, and draws a post with its date and picture" do
    get "/blog"

    # As getAllPosts sorted them: by when each was written (Directus's date_created).
    posts = CollectionEntry.joins(:collection).where(collections: {slug: "blog"}).order(:id).to_a
    posts.each_with_index { |post, index| post.update_columns(created_at: index.days.ago) }
    get "/blog"
    expect(html.css(".post-card h3").map(&:text)).to eq(posts.map(&:title))

    get "/blog/tips-and-tricks-to-make-your-move-easier"
    expect(html.at_css("h1").text).to eq("Tips & Tricks to Make Your Move Easier")
    expect(html.at_css(".post__date").text).to eq("October 24, 2022")
    expect(html.at_css(".post__image")).to be_present
  end

  it "draws the comparison, the what-fits chart and the hourly movers from their blocks" do
    get "/moving"
    expect(html.css(".comparison__table tbody tr").size).to eq(6)

    get "/what-fits-in-a-mule-box"
    expect(html.css(".what-fits__table tbody tr").size).to eq(6)

    get "/hourly-movers"
    expect(html.css(".movers__table tr").map { it.at_css("td").text.squish }.first).to eq("PiggyBack Moving (opens in a new tab) | 817.380.5665")
  end

  it "sends a quote request on to the thank-you page, and the franchise form to its own" do
    get "/quote"
    expect(html.at_css("form[data-form=quote]")["data-redirect"]).to eq("/quote-thank-you")

    get "/franchisee-opportunities"
    expect(html.at_css("form[data-form=franchise]")["data-redirect"]).to eq("/thank-you-franchise")
  end

  it "draws the nav's dropdowns and the footer's columns" do
    get "/"

    expect(html.css("header .navbar__parent").map { it.text.strip }).to eq(%w[Locations Services])
    expect(html.css("header #nav-menu-0 a").map { it.text.strip }).to eq(["All Locations", "TX - Austin", "CA - Bay Area", "LA - Bossier City", "TX - Dallas/Fort Worth"])
    expect(html.css("footer .site-footer__column h2").map(&:text)).to eq(["services", "support", "Social Media"])
    expect(html.at_css("footer .site-footer__bottom p").text).to include("© #{Time.current.year} Mule Box")
  end

  it "takes its colors from the design settings" do
    get "/"
    expect(html.at_css("meta[name=theme-color]")["content"]).to eq("#852d33")

    Website::Design.update(Website.theme, "accent" => "#112233", "secondary" => "#445566")
    get "/"
    expect(html.at_css("meta[name=theme-color]")["content"]).to eq("#112233")
    expect(html.css("style").map(&:text).join).to include("#445566")
  end

  it "keeps its links working in the editor's preview, where text carries inline-edit marks" do
    sign_in_as create(:user)
    home = Page.find_by!(path: "home")
    blocks = Array(home.blocks).each_with_index.to_h { |block, index| [index.to_s, {"_json" => block.to_json}] }

    patch page_path(home.slug, website_preview: 1), params: {page: {title: home.title, slug: home.slug, status: "published", lock_version: home.lock_version, blocks:}}

    expect(response).to have_http_status(:ok)
    marks = Regexp.union(Website::InlineEdit::START, Website::InlineEdit::FINISH, *Website::InlineEdit::DIGITS)
    expect(response.body).to match(marks)
    addresses = html.css("[href], [action], [data-redirect]").flat_map { |node| %w[href action data-redirect].filter_map { node[it] } }
    expect(addresses.grep(marks)).to be_empty
    expect(html.css(".mule-hero__buttons a").map { it["href"] }).to eq(["/quote", "/how-it-works"])
  end
end
