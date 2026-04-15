require "application_system_test_case"

class CalendarBulkEditTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @view = event_calendar_views(:vendor_view)
    @ceremony = calendar_items(:ceremony)
    @reception = calendar_items(:reception)
  end

  test "run of show bulk edit requires confirmation before applying vendor changes" do
    login_as_planner
    visit event_calendar_path(@event)

    assert_no_selector ".event-calendars__bulk-toolbar", visible: true

    check_bulk_item(@ceremony)

    assert_selector ".event-calendars__bulk-toolbar", visible: true
    assert_selector ".event-calendars__bulk-count", text: /1\s+selected/

    find("select[name='bulk[bulk_action]']").select("Set vendor")
    fill_in "Vendor", with: "Golden Pine Events"

    click_button "Apply"
    assert_selector "dialog[open]"

    click_button "Cancel"
    assert_nil @ceremony.reload.vendor_name

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_path(@event)
    assert_text "Vendor updated for 1 item."
    assert_equal "Golden Pine Events", @ceremony.reload.vendor_name
  end

  test "run of show filter bar uses labeled sections and wide desktop alignment" do
    login_as_planner
    page.current_window.resize_to(1800, 1400)
    visit event_calendar_path(@event)

    assert_selector ".event-calendars__filter-section--search .event-calendars__filter-section-label", text: /Search/i
    assert_selector ".event-calendars__filter-section--filters .event-calendars__filter-section-label", text: /Filters/i
    assert_selector ".event-calendars__filter-section--controls .event-calendars__filter-section-label", text: /Controls/i
    assert_selector ".event-calendars__filter-section--filters .event-calendars__filter-dropdown", count: 4
    assert_selector ".event-calendars__filter-section--controls .event-calendars__bulk-button", count: 2

    layout = page.evaluate_script(<<~JS)
      (() => {
        const topPositions = (selector) => Array.from(document.querySelectorAll(selector)).map((node) => node.getBoundingClientRect().top)
        const aligned = (values) => values.length > 1 && Math.max(...values) - Math.min(...values) < 3
        const height = (selector) => {
          const node = document.querySelector(selector)
          return node ? node.getBoundingClientRect().height : null
        }

        return {
          filtersAligned: aligned(topPositions(".event-calendars__filter-section--filters .event-calendars__filter-dropdown")),
          controlsAligned: aligned(topPositions(".event-calendars__filter-section--controls .event-calendars__bulk-button")),
          searchHeight: height(".event-calendars__filter-search-input"),
          dropdownHeight: height(".event-calendars__filter-section--filters .event-calendars__filter-summary"),
          buttonHeight: height(".event-calendars__filter-section--controls .event-calendars__bulk-button")
        }
      })()
    JS

    assert layout["filtersAligned"]
    assert layout["controlsAligned"]
    assert_in_delta layout["searchHeight"], layout["dropdownHeight"], 2
    assert_in_delta layout["searchHeight"], layout["buttonHeight"], 2
  end

  test "run of show search matches title vendor location notes and team text" do
    login_as_planner
    visit event_calendar_path(@event)

    [
      ["Ceremony", @ceremony],
      ["Bloom & Co.", calendar_items(:decision_flowers)],
      ["Grand Ballroom", @ceremony],
      ["Exchange vows and rings.", @ceremony],
      ["Ada Fixture", @ceremony],
      ["Temp Contractor", calendar_items(:afterparty)]
    ].each do |query, item|
      fill_in_timeline_search(query)

      assert_selector "tr##{ActionView::RecordIdentifier.dom_id(item, :timeline_row)}", visible: true
    end

    fill_in_timeline_search("No Matching Timeline Item")
    assert_text "No items match the current search or filters."
  end

  test "run of show search highlights visible matches across searchable fields" do
    login_as_planner
    visit event_calendar_path(@event)

    [
      ["Ceremony", @ceremony],
      ["Bloom & Co.", calendar_items(:decision_flowers)],
      ["Grand Ballroom", @ceremony],
      ["Exchange vows and rings.", @ceremony],
      ["Ada Fixture", @ceremony],
      ["Temp Contractor", calendar_items(:afterparty)]
    ].each do |query, item|
      fill_in_timeline_search(query)

      assert_selector "tr##{ActionView::RecordIdentifier.dom_id(item, :timeline_row)}", visible: true
      assert_highlight_state(expected_present: true)
    end

    fill_in_timeline_search("")
    assert_highlight_state(expected_present: false)
  end

  test "run of show selection persists across search changes and select all counts visible rows" do
    login_as_planner
    visit event_calendar_path(@event)

    check_bulk_item(@ceremony)

    assert_selector ".event-calendars__bulk-toolbar", visible: true
    assert_selector ".event-calendars__bulk-count", text: /1\s+selected/

    fill_in_timeline_search("Reception")

    assert_text "Reception"
    assert_no_text "Ceremony"

    within ".event-calendars__filter-bar" do
      click_button "Select all 1 item"
    end

    assert_selector ".event-calendars__bulk-count", text: /2\s+selected/
    assert_selector ".event-calendars__filter-actions button", text: "Deselect all 1 item"
    assert_selector ".event-calendars__bulk-shortcuts button", text: "Deselect all 1 item"

    within ".event-calendars__filter-actions" do
      click_button "Deselect all 1 item"
    end

    assert_selector ".event-calendars__bulk-count", text: /1\s+selected/
    assert_selector "input.event-calendars__bulk-checkbox[value='#{@ceremony.id}']:checked", visible: :all
    assert_no_selector "input.event-calendars__bulk-checkbox[value='#{@reception.id}']:checked", visible: :all

    within ".event-calendars__bulk-toolbar" do
      click_button "Deselect all"
    end
    assert_no_selector ".event-calendars__bulk-toolbar", visible: true
  end

  test "run of show tag facet filters tagged and untagged rows" do
    login_as_planner
    visit event_calendar_path(@event)

    open_filter("Tags")
    set_filter_value("tag", "vendor", true)

    assert_text "Reception"
    assert_text "Afterparty"
    assert_no_text "Ceremony"
    assert_no_text "Select Florist"

    set_filter_value("tag", "__none__", true)

    assert_text "Ceremony"
    assert_text "Select Florist"
  end

  test "run of show filter dropdowns close when clicking outside the menu" do
    login_as_planner
    visit event_calendar_path(@event)

    open_filter("Vendor")
    assert_selector "details.event-calendars__filter-dropdown[open]", count: 1

    page.execute_script(<<~JS)
      document.body.dispatchEvent(new MouseEvent("click", { bubbles: true }))
    JS

    assert_no_selector "details.event-calendars__filter-dropdown[open]"
  end

  test "run of show clear search and filters resets the current state" do
    login_as_planner
    visit event_calendar_path(@event)

    fill_in_timeline_search("Florist")
    open_filter("Vendor")
    set_filter_value("vendor", "bloom-co", true)
    open_filter("Tags")
    set_filter_value("tag", "vendor", true)

    assert_text "No items match the current search or filters."

    click_button "Clear search/filters"

    assert_equal "", find("input[aria-label='Search timeline']").value
    assert_text "Ceremony"
    assert_text "Reception"
    assert_text "Afterparty"
    assert_text "Select Florist"
    assert_selector ".event-calendars__filter-summary-values", text: "All", minimum: 4
    assert_no_text "No items match the current search or filters."
  end

  test "run of show filters combine vendor location and team selections including none" do
    login_as_planner
    visit event_calendar_path(@event)

    open_filter("Vendor")
    set_filter_value("vendor", "__none__", true)
    set_filter_value("vendor", "bloom-co", true)

    assert_text "Ceremony"
    assert_text "Select Florist"

    open_filter("Location")
    set_filter_value("location", "grand-ballroom", true)

    assert_text "Ceremony"
    assert_no_text "Select Florist"
    assert_no_text "Reception"

    open_filter("Team")
    set_filter_value("team", "ada-fixture", true)

    assert_text "Ceremony"
    assert_no_text "Afterparty"
  end

  test "run of show hides empty date groups while filtering" do
    login_as_planner
    visit event_calendar_path(@event)

    fill_in_timeline_search("Ceremony")

    assert_selector ".event-calendars__date-label", text: /Wednesday, October 1/i
    assert_no_selector ".event-calendars__date-label", text: /Monday, September 15/i
    assert_no_selector ".event-calendars__date-label", text: /Saturday, September 20/i
  end

  test "run of show highlights clear for filter-only states and hidden matches do not contribute" do
    login_as_planner
    visit event_calendar_path(@event)

    open_filter("Tags")
    set_filter_value("tag", "vendor", true)

    assert_highlight_state(expected_present: false)

    fill_in_timeline_search("Reception")
    assert_selector "tr##{ActionView::RecordIdentifier.dom_id(@reception, :timeline_row)}", visible: true
    assert_highlight_state(expected_present: true)

    set_filter_value("tag", "vendor", false)
    set_filter_value("tag", "__none__", true)

    assert_no_text "Reception"
    assert_highlight_state(expected_present: false)
  end

  test "derived calendar bulk removal stays on the derived view and updates the filtered results" do
    login_as_planner
    visit event_calendar_view_path(@event, @view)

    assert_text "Reception"
    assert_no_text "Afterparty"

    check_bulk_item(@reception)
    assert_selector ".event-calendars__bulk-toolbar", visible: true
    find("select[name='bulk[bulk_action]']", visible: :all).select("Remove tags")
    find("input#bulk_tag_#{event_calendar_tags(:vendor).id}", visible: :all).set(true)

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_view_path(@event, @view)
    assert_text "No items match this view yet."
    assert_not_includes @reception.reload.event_calendar_tag_ids, event_calendar_tags(:vendor).id
  end

  test "run of show bulk edit can set and clear time labels" do
    login_as_planner
    visit event_calendar_path(@event)

    check_bulk_item(@ceremony)
    find("select[name='bulk[bulk_action]']").select("Set time label")
    fill_in "Time label", with: "Morning"

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_path(@event)
    assert_text "Time label updated for 1 item."
    within "tr##{ActionView::RecordIdentifier.dom_id(@ceremony, :timeline_row)}" do
      assert_text "Morning"
      assert_no_text "3:00 PM – 3:45 PM"
    end

    check_bulk_item(@ceremony)
    find("select[name='bulk[bulk_action]']").select("Clear time label")

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_path(@event)
    assert_text "Time label cleared for 1 item."
    within "tr##{ActionView::RecordIdentifier.dom_id(@ceremony, :timeline_row)}" do
      assert_text "3:00 PM – 3:45 PM"
      assert_no_text "Morning"
    end
  end

  test "planner timeline bulk edit can add and remove pp members" do
    login_as_planner
    visit event_calendar_view_path(@event, @view)

    check_bulk_item(@reception)
    find("select[name='bulk[bulk_action]']").select("Add PP members")
    find("input#bulk_team_member_#{users(:one).id}", visible: :all).set(true)

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_view_path(@event, @view)
    assert_text "PP members added to 1 item."
    within "tr##{ActionView::RecordIdentifier.dom_id(@reception, :timeline_row)}" do
      assert_text "Ada Fixture, Grace Fixture"
    end

    check_bulk_item(@reception)
    find("select[name='bulk[bulk_action]']").select("Remove PP members")
    find("input#bulk_team_member_#{users(:two).id}", visible: :all).set(true)

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_view_path(@event, @view)
    assert_text "PP members removed from 1 item."
    within "tr##{ActionView::RecordIdentifier.dom_id(@reception, :timeline_row)}" do
      assert_text "Ada Fixture"
      assert_no_text "Grace Fixture"
    end
  end

  test "planner timeline bulk edit can set and clear other people" do
    login_as_planner
    visit event_calendar_view_path(@event, @view)

    check_bulk_item(@reception)
    find("select[name='bulk[bulk_action]']").select("Set other people")
    fill_in "Other people", with: "DJ; Florist"

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_view_path(@event, @view)
    assert_text "Other people updated for 1 item."
    within "tr##{ActionView::RecordIdentifier.dom_id(@reception, :timeline_row)}" do
      assert_text "Grace Fixture; DJ; Florist"
    end

    check_bulk_item(@reception)
    find("select[name='bulk[bulk_action]']").select("Clear other people")

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_view_path(@event, @view)
    assert_text "Other people cleared for 1 item."
    within "tr##{ActionView::RecordIdentifier.dom_id(@reception, :timeline_row)}" do
      assert_text "Grace Fixture"
      assert_no_text "DJ; Florist"
    end
  end

  private

  def open_filter(label)
    find("summary.event-calendars__filter-summary", text: /#{Regexp.escape(label)}/i).click
  end

  def set_filter_value(facet, value, checked)
    find("input[data-filter-facet='#{facet}'][value='#{value}']").set(checked)
  end

  def fill_in_timeline_search(value)
    find("input[aria-label='Search timeline']").set(value)
  end

  def check_bulk_item(item)
    page.execute_script(<<~JS)
      (() => {
        const checkbox = document.querySelector("input.event-calendars__bulk-checkbox[value='#{item.id}']")
        if (!checkbox) return

        checkbox.checked = true
        checkbox.dispatchEvent(new Event("change", { bubbles: true }))
      })()
    JS
  end

  def assert_highlight_state(expected_present:, minimum_range_count: 1)
    supported = page.evaluate_script(<<~JS)
      Boolean(window.CSS && CSS.highlights && typeof CSS.highlights.has === "function" && typeof window.Highlight === "function")
    JS

    return unless supported

    if expected_present
      assert page.evaluate_script("CSS.highlights.has('calendar-bulk-edit-search-match')")
      assert_operator page.evaluate_script("CSS.highlights.get('calendar-bulk-edit-search-match').size"), :>=, minimum_range_count
    else
      assert_not page.evaluate_script("CSS.highlights.has('calendar-bulk-edit-search-match')")
    end
  end
end
