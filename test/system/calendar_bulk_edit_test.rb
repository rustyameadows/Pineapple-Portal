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

  test "run of show relative timing sheet offers two relationship choices" do
    login_as_planner
    visit event_calendar_path(@event)

    check_bulk_item(@ceremony)
    check_bulk_item(@reception)

    click_button "Change relative timing"

    within "dialog[open]" do
      top_row_anchor = ActionView::RecordIdentifier.dom_id(@ceremony, :timeline_row)
      assert_equal "#{event_calendar_path(@event)}##{top_row_anchor}",
                   find("[data-calendar-bulk-edit-target='timingReturnToInput']", visible: :all).value
      assert_text "Choose which relationship to save."
      assert_no_text "Move item"
      assert_no_text "Anchor item"
      assert_no_button "Swap"
      assert_no_selector "select[data-calendar-bulk-edit-target='relativeAnchorPointSelect']"
      assert_button "Ceremony will start 2 hr before Reception starts → Oct 1 3:00PM"
      assert_button "Reception will start 2 hr after Ceremony starts → Oct 1 5:00PM"
      assert_button "Anchor to selected item start", disabled: true
      assert_button "Anchor to selected item end", disabled: true
      assert_selector "button[data-calendar-bulk-edit-target='timingSubmitButton'][disabled]"

      find("[data-calendar-bulk-edit-target='relativeTimingOption'][data-timing-option-index='1']").click
      assert_button "Anchor to Ceremony start"
      assert_button "Anchor to Ceremony end"
      assert_selector "button[data-calendar-bulk-edit-target='timingSubmitButton'][disabled]"

      find("[data-calendar-bulk-edit-target='relativeAnchorPointOption'][data-timing-anchor-point='end']").click
      assert_button "Reception will start 1 hr 15 min after Ceremony ends → Oct 1 5:00PM"
      assert_equal @reception.id.to_s, find("[data-calendar-bulk-edit-target='timingTargetInput']", visible: :all).value
      assert_equal @ceremony.id.to_s, find("[data-calendar-bulk-edit-target='timingAnchorInput']", visible: :all).value
      assert_equal "end", find("[data-calendar-bulk-edit-target='timingAnchorPointInput']", visible: :all).value
      assert_no_selector "button[data-calendar-bulk-edit-target='timingSubmitButton'][disabled]"
    end
  end

  test "run of show same-time move buttons only show available directions" do
    first, second, third = create_same_time_items

    login_as_planner
    visit event_calendar_path(@event)

    check_bulk_item(first)
    assert_no_same_time_move_button("up")
    assert_same_time_move_button("down")

    check_only_bulk_item(second)
    assert_same_time_move_button("up")
    assert_same_time_move_button("down")

    check_only_bulk_item(third)
    assert_same_time_move_button("up")
    assert_no_same_time_move_button("down")

    check_bulk_item(second)
    assert_no_same_time_move_button("up")
    assert_no_same_time_move_button("down")

    within ".event-calendars__bulk-toolbar" do
      click_button "Deselect all"
    end

    solo = @event.run_of_show_calendar.calendar_items.create!(
      title: "Solo Same-Time Item",
      starts_at: Time.zone.parse("2025-10-01 16:30"),
      duration_minutes: 30,
      position: 103
    )

    check_bulk_item(solo)
    assert_no_same_time_move_button("up")
    assert_no_same_time_move_button("down")
  end

  test "run of show same-time move updates row order after redirect" do
    first, second = create_same_time_items.first(2)

    login_as_planner
    visit event_calendar_path(@event)

    assert_row_before(first, second)

    check_bulk_item(second)
    click_same_time_move_button("up")

    assert_current_path event_calendar_path(@event)
    assert_text "Order updated."
    assert_row_before(second, first)
    assert_equal ["Second Same-Time Item", "First Same-Time Item", "Third Same-Time Item"], same_time_titles
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

  test "run of show group headers can select and deselect all visible rows in the group" do
    login_as_planner
    visit event_calendar_path(@event)

    within find("tr.event-calendars__date-row", text: /Wednesday, October 1/i) do
      click_button "Select"
    end

    assert_selector ".event-calendars__bulk-toolbar", visible: true
    assert_selector ".event-calendars__bulk-count", text: /3\s+selected/
    assert_selector "input.event-calendars__bulk-checkbox[value='#{@ceremony.id}']:checked", visible: :all
    assert_selector "input.event-calendars__bulk-checkbox[value='#{@reception.id}']:checked", visible: :all
    assert_selector "input.event-calendars__bulk-checkbox[value='#{calendar_items(:afterparty).id}']:checked", visible: :all
    assert_no_selector "input.event-calendars__bulk-checkbox[value='#{calendar_items(:decision_flowers).id}']:checked", visible: :all

    within find("tr.event-calendars__date-row", text: /Wednesday, October 1/i) do
      click_button "Deselect"
    end

    assert_no_selector ".event-calendars__bulk-toolbar", visible: true
    assert_no_selector "input.event-calendars__bulk-checkbox[value='#{@ceremony.id}']:checked", visible: :all
    assert_no_selector "input.event-calendars__bulk-checkbox[value='#{@reception.id}']:checked", visible: :all
    assert_no_selector "input.event-calendars__bulk-checkbox[value='#{calendar_items(:afterparty).id}']:checked", visible: :all
  end

  test "master decisions can filter select a segment and bulk update status with confirmation" do
    decision_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Decisions")
    flowers = calendar_items(:decision_flowers)
    catering = calendar_items(:decision_catering)
    [flowers, catering].each { |item| item.event_calendar_tags << decision_tag }

    login_as_planner
    visit decisions_path

    assert_selector ".event-calendars__filter-summary-label", text: /event/i
    assert_selector ".event-calendars__filter-summary-label", text: /status/i
    assert_no_selector ".event-calendars__filter-summary-label", text: /vendor/i

    fill_in_timeline_search("Florist")
    assert_text "Select Florist"
    assert_no_text "Approve Catering Menu"

    fill_in_timeline_search("")
    open_filter("Status")
    set_filter_value("status", "planned", true)

    assert_text "Approve Catering Menu"
    assert_no_text "Select Florist"

    within find("tr.event-calendars__date-row", text: /September 2025/i) do
      click_button "Select"
    end

    assert_selector ".event-calendars__bulk-toolbar", visible: true
    assert_selector ".event-calendars__bulk-count", text: /1\s+selected/

    click_button "Mark as In Progress"
    assert_selector "dialog[open]", text: "mark as in progress"
    assert_equal "planned", catering.reload.status

    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_text "Status updated for 1 decision."
    assert_equal "in_progress", catering.reload.status
    assert_equal "in_progress", flowers.reload.status
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

  def check_only_bulk_item(item)
    page.execute_script(<<~JS)
      (() => {
        document.querySelectorAll("input.event-calendars__bulk-checkbox").forEach((checkbox) => {
          checkbox.checked = false
        })
      })()
    JS
    check_bulk_item(item)
  end

  def same_time_move_selector(direction)
    "button[data-calendar-bulk-edit-target='sameTimeMove#{direction.camelize}Button']"
  end

  def assert_same_time_move_button(direction)
    assert_selector same_time_move_selector(direction), text: "Move #{direction}", visible: true
  end

  def assert_no_same_time_move_button(direction)
    assert_no_selector same_time_move_selector(direction), text: "Move #{direction}", visible: true
  end

  def click_same_time_move_button(direction)
    find(same_time_move_selector(direction), text: "Move #{direction}", visible: true).click
  end

  def assert_row_before(first, second)
    first_id = ActionView::RecordIdentifier.dom_id(first, :timeline_row)
    second_id = ActionView::RecordIdentifier.dom_id(second, :timeline_row)

    assert page.evaluate_script(<<~JS)
      (() => {
        const first = document.getElementById("#{first_id}")
        const second = document.getElementById("#{second_id}")
        return Boolean(first && second && (first.compareDocumentPosition(second) & Node.DOCUMENT_POSITION_FOLLOWING))
      })()
    JS
  end

  def create_same_time_items
    [
      @event.run_of_show_calendar.calendar_items.create!(title: "First Same-Time Item", starts_at: Time.zone.parse("2025-10-01 16:00:30"), duration_minutes: 30, position: 100),
      @event.run_of_show_calendar.calendar_items.create!(title: "Second Same-Time Item", starts_at: Time.zone.parse("2025-10-01 16:00:45"), duration_minutes: 30, position: 101),
      @event.run_of_show_calendar.calendar_items.create!(title: "Third Same-Time Item", starts_at: Time.zone.parse("2025-10-01 16:00:15"), duration_minutes: 30, position: 102)
    ]
  end

  def same_time_titles
    @event.run_of_show_calendar.calendar_items
          .select { |item| item.effective_starts_at&.utc&.change(sec: 0) == Time.zone.parse("2025-10-01 16:00").utc }
          .sort_by { |item| [item.position.to_i, item.title.to_s.downcase, item.id.to_i] }
          .map(&:title)
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
