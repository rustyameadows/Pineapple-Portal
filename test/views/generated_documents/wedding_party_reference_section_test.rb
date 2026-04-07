require "test_helper"

class WeddingPartyReferenceSectionTest < ActionView::TestCase
  fixtures :events

  setup do
    @event = events(:one)
    @segment = DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Wedding Party Reference",
      source_ref: {
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "options" => {}
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "label" => "Wedding Party Reference"
      }
    )

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.assign(event: @event, segment: @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
  end

  test "renders the wedding party reference sheet structure with stubbed content" do
    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference", count: 1
    assert_select ".generated-template--packet-sheet__two-column", minimum: 2
    assert_select ".generated-template--packet-sheet__section-title", text: "Event Timelines"
    assert_select ".generated-template--packet-sheet__section-title", text: "Transportation Details"
    assert_select ".generated-template--packet-sheet__section-title", text: "Oktoberfest Excursions"
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details & Transportation"
    assert_select ".generated-template--packet-sheet__section-title", text: "Bride's Side"
    assert_select ".generated-template--packet-sheet__section-title", text: "Groom's Side"
    assert_select ".generated-template--packet-sheet__subsection-title", text: "Friday, August 29"
    assert_match(/Ceremony Rehearsal/, rendered)
    assert_match(/Pierce Arrow Board Room/, rendered)
    assert_match(/Hannah Isakowitz/, rendered)
    assert_match(/Dan Greener/, rendered)
    assert_no_match(/generated-text-columns|:::columns|### Wedding party reference sheet/, rendered)
  end
end
