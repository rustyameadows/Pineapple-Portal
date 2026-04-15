require "test_helper"

class PageNumberOverlayTest < ActionView::TestCase
  setup do
    view.extend DocumentsHelper
    view.assign(
      page_label: "Pg. 1",
      page_width_points: 612,
      page_height_points: 792,
      page_text_color: "#ffffff"
    )
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
  end

  test "renders the styled page number overlay with the display font" do
    render template: "generated_documents/page_number_overlay"

    assert_select ".generated-page-number-overlay__label", text: "Pg. 1"
    assert_match(/font-family:\s*var\(--font-family-display/m, rendered)
    assert_match(/font-size:\s*16px/m, rendered)
    assert_match(/font-style:\s*italic/m, rendered)
    assert_match(/color:\s*#ffffff/m, rendered)
    assert_match(/@font-face/m, rendered)
    assert_match(/data:font\/woff2;base64,stub/m, rendered)
  end
end
