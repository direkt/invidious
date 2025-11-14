require "../spec_helper"

Spectator.describe Invidious::Frontend::ChannelPage do
  it "renders Shorts tab link and selects it when active" do
    channel = AboutChannel.new(
      ucid: "UC123",
      author: "Author",
      auto_generated: false,
      author_url: "https://www.youtube.com/channel/UC123",
      author_thumbnail: "https://yt/img.jpg",
      banner: nil,
      description: "",
      description_html: "",
      total_views: 0_i64,
      sub_count: 0,
      joined: Time.unix(0),
      is_family_friendly: true,
      allowed_regions: [] of String,
      tabs: ["videos", "shorts", "streams"],
      tags: [] of String,
      verified: false,
      is_age_gated: false,
    )

    html = Invidious::Frontend::ChannelPage.generate_tabs_links("en-US", channel, Invidious::Frontend::ChannelPage::TabsAvailable::Shorts)

    expect(html).to contain("<b>Shorts</b>")
    expect(html).to contain("href=\"/channel/UC123\"") # videos tab link exists
  end
end

