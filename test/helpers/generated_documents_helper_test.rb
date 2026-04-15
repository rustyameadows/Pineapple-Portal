require "test_helper"

class GeneratedDocumentsHelperTest < ActionView::TestCase
  include DocumentsHelper
  include GeneratedDocumentsHelper

  test "renders packet rich text with normalized headings and safe links" do
    html = render_generated_packet_rich_text(
      "## Arrival Notes\n\n**Check in** with the desk.\n\n*Bring* your badge.\n\n[Parking map](https://example.com/map)\n\n[Unsafe](javascript:alert(1))"
    )
    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    heading = fragment.at_css("h3.generated-template--packet-sheet__subsection-title")
    safe_link = fragment.at_css("a[href='https://example.com/map']")
    unsafe_link = fragment.css("a").find { |link| link.text == "Unsafe" }

    assert_not_nil heading
    assert_equal "Arrival Notes", heading.text.strip
    assert_not_nil fragment.at_css("strong")
    assert_not_nil fragment.at_css("em")
    assert_not_nil safe_link
    assert_equal "_blank", safe_link["target"]
    assert_equal "noopener noreferrer", safe_link["rel"]
    assert_not_nil unsafe_link
    assert_nil unsafe_link["href"]
  end

  test "pdf_asset_url prefixes relative paths but preserves absolute and data urls" do
    helper = ActionController::Base.helpers

    helper.stub :asset_path, ->(path) { path } do
      assert_equal "http://localhost:3000/assets/fonts/Didot.woff2", pdf_asset_url("assets/fonts/Didot.woff2")
    end

    helper.stub :asset_path, ->(path) { path } do
      assert_equal "data:font/woff2;base64,AAAA", pdf_asset_url("data:font/woff2;base64,AAAA")
    end

    helper.stub :asset_path, ->(path) { path } do
      assert_equal "https://cdn.example.test/assets/fonts/Didot.woff2", pdf_asset_url("https://cdn.example.test/assets/fonts/Didot.woff2")
    end

    helper.stub :asset_path, ->(path) { path } do
      assert_equal "//cdn.example.test/assets/fonts/Didot.woff2", pdf_asset_url("//cdn.example.test/assets/fonts/Didot.woff2")
    end
  end

  test "inline_asset_data_uri resolves font assets through propshaft" do
    data_uri = inline_asset_data_uri("Didot.woff2")

    assert data_uri.present?
    assert_match(/\Adata:font\/woff2;base64,/, data_uri)
  end
end
