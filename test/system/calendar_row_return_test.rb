require "application_system_test_case"

class CalendarRowReturnTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    calendar = event_calendars(:run_of_show)
    position = calendar.calendar_items.maximum(:position).to_i + 1

    35.times do |index|
      calendar.calendar_items.create!(
        title: "Timeline filler #{index + 1}",
        starts_at: Time.zone.parse("2025-10-02 08:00") + index.hours,
        duration_minutes: 30,
        position: position + index
      )
    end

    @item = calendar.calendar_items.create!(
      title: "Anchor target item",
      starts_at: Time.zone.parse("2025-10-04 18:00"),
      duration_minutes: 45,
      position: position + 35
    )
  end

  test "editing a run of show item returns to the edited row, highlights it, and clears the helper hash" do
    login_as_planner
    visit event_calendar_path(@event)

    row_anchor = ActionView::RecordIdentifier.dom_id(@item, :timeline_row)

    within("tr##{row_anchor}") do
      find("a.event-calendars__title-link", text: @item.title).click
    end

    fill_in "Title", with: "Anchor target item updated"
    find("input[type='submit']", visible: true).click

    assert_text "Calendar item updated."
    assert_text "Anchor target item updated"
    assert_operator page.evaluate_script("window.scrollY"), :>, 0
    assert page.evaluate_script(<<~JS)
      (() => {
        const row = document.getElementById("#{row_anchor}")
        if (!row) return false

        const rect = row.getBoundingClientRect()
        return rect.top >= 0 && rect.top < window.innerHeight && rect.bottom > 0
      })()
    JS
    assert page.evaluate_script(<<~JS)
      (() => {
        const row = document.getElementById("#{row_anchor}")
        return row ? row.classList.contains("event-calendars__row--return-highlight") : false
      })()
    JS
    assert_equal "", page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      setTimeout(() => done(window.location.hash), 350)
    JS
    assert_equal false, page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      setTimeout(() => {
        const row = document.getElementById("#{row_anchor}")
        done(row ? row.classList.contains("event-calendars__row--return-highlight") : false)
      }, 3200)
    JS
  end

  private

  def login_as_planner
    visit login_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password123"
    click_button "Log In"
    assert_text "Your Active Events"
  end
end
