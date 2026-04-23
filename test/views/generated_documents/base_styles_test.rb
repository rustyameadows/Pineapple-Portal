require "test_helper"

class BaseStylesTest < ActionView::TestCase
  setup do
    view.extend DocumentsHelper
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
  end

  test "defaults generated template horizontal padding to 0.7 inches" do
    render partial: "generated_documents/sections/base_styles"

    assert_match(/--page-content-padding-x:\s*var\(--generated-document-content-padding-x,\s*0\.7in\)/m, rendered)
  end
end
