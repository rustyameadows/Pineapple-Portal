require "test_helper"

class GeneratedDocumentsHelperTest < ActionView::TestCase
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
end
