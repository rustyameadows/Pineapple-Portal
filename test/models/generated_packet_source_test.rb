require "test_helper"

class GeneratedPacketSourceTest < ActiveSupport::TestCase
  fixtures :events

  test "ensure_canonical normalizes wedding party reference sources to the generated template" do
    event = events(:one)
    existing = event.generated_packet_sources.create!(
      source_category: GeneratedPacketSource::CATEGORIES[:canonical],
      canonical_key: GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference],
      kind: GeneratedPacketSource::KINDS[:html_view],
      title: "Wedding Party Reference",
      source_ref: {
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "options" => {
          "body_markdown" => "Legacy content"
        }
      },
      spec: {
        "kind" => GeneratedPacketSource::KINDS[:html_view],
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "label" => "Wedding Party Reference"
      }
    )

    canonical = GeneratedPacketSource.ensure_canonical!(event, :wedding_party_reference)

    assert_equal existing.id, canonical.id
    assert_equal DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY, canonical.html_view_key
    assert_equal({}, canonical.html_options)
  end
end
