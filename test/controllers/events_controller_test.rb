require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:one)
    @other_event = events(:two)
    log_in_as(users(:one))
  end

  test "lists events table with active rows first and archived rows below" do
    @event.update!(archived_at: 2.days.ago)

    get events_url

    assert_response :success
    assert_select "h1.event-section__title", text: "All Events"
    assert_select "table.events-all__table", count: 1
    assert_select ".event-card", count: 0

    body = @response.body
    active_index = body.index(@other_event.name)
    divider_index = body.index("Archived Events")
    archived_index = body.index(@event.name)

    assert_not_nil active_index
    assert_not_nil divider_index
    assert_not_nil archived_index
    assert_operator active_index, :<, divider_index
    assert_operator divider_index, :<, archived_index
  end

  test "active row renders archive control" do
    get events_url

    assert_response :success
    assert_select "a[href='#{archive_event_path(@event, return_to: events_path)}'][data-turbo-method='patch'][data-turbo-confirm='Archive this event? It will move to archived events.']", text: "Archive"
  end

  test "archived row renders restore control" do
    @event.update!(archived_at: Time.current)

    get events_url

    assert_response :success
    assert_select "a[href='#{restore_event_path(@event, return_to: events_path)}'][data-turbo-method='patch'][data-turbo-confirm='Restore this event to active projects?']", text: "Restore"
  end

  test "renders styled new event page" do
    get new_event_url

    assert_response :success
    assert_select ".event-layout.event-layout--index"
    assert_select "h1.event-section__title", text: "Create Event"
    assert_select "a.event-section__link[href='#{events_path}']", text: "Back to events"
    assert_select "form.event-create-form", count: 1
    assert_select "input[name='event[name]']"
    assert_select "input[name='event[starts_on]']"
    assert_select "input[name='event[ends_on]']"
    assert_select "input[name='event[location]']"
    assert_select "input[name='event[location_secondary]']"
  end

  test "renders styled edit event page" do
    get edit_event_url(@event)

    assert_response :success
    assert_select ".event-layout.event-layout--index"
    assert_select "h1.event-section__title", text: "Edit Event"
    assert_select "a.event-section__link[href='#{event_path(@event)}']", text: "Back to event"
    assert_select "form.event-create-form", count: 1
  end

  test "updates portal slug from client portal settings" do
    patch event_url(@event), params: {
      event: { portal_slug: "launch-weekend" },
      return_to: client_portal_event_settings_path(@event)
    }

    assert_redirected_to client_portal_event_settings_url(@event)
    assert_equal "launch-weekend", @event.reload.portal_slug
  end

  test "rerenders client portal settings when portal slug is taken" do
    patch event_url(@event), params: {
      event: { portal_slug: @other_event.portal_slug },
      return_to: client_portal_event_settings_path(@event)
    }

    assert_response :unprocessable_content
    assert_select "h1", text: "Portal URL"
    assert_select "div.event-settings__form-errors li", text: "Portal slug has already been taken"
    assert_select "input[name='event[portal_slug]'][value='#{@other_event.portal_slug}']", count: 1
  end

  test "rerenders general settings when event details update is invalid" do
    patch event_url(@event), params: {
      event: { name: "" },
      return_to: event_settings_path(@event)
    }

    assert_response :unprocessable_content
    assert_select "form.event-settings__details-form", count: 1
    assert_select "div.event-settings__form-errors li", text: "Name can't be blank"
    assert_select "input[name='event[name]'][value='']", count: 1
    assert_select "h1", text: "Edit Event", count: 0
  end

  test "creates event" do
    assert_difference("Event.count") do
      post events_url, params: { event: { name: "Rehearsal", starts_on: "2025-12-01" } }
    end

    assert_redirected_to event_url(Event.last)
  end

  test "invalid create rerenders styled form with errors" do
    assert_no_difference("Event.count") do
      post events_url, params: { event: { name: "", starts_on: "2025-12-01" } }
    end

    assert_response :unprocessable_content
    assert_select ".event-create-form__errors", count: 1
    assert_select ".event-create-form__errors li", text: "Name can't be blank"
  end

  test "archives event and removes from active card stack" do
    patch archive_event_path(@event), params: { return_to: events_path }

    assert_redirected_to events_url
    assert_equal "Event archived.", flash[:notice]

    @event.reload
    assert @event.archived?

    get events_url
    assert_select ".events-all__row--active .events-all__event-link", text: @event.name, count: 0
    assert_select ".events-all__row--archived .events-all__event-link", text: @event.name, count: 1
  end

  test "restores archived event" do
    @event.update!(archived_at: Time.current)

    patch restore_event_path(@event), params: { return_to: events_path }

    assert_redirected_to events_url
    assert_equal "Event restored.", flash[:notice]

    @event.reload
    assert_not @event.archived?
  end

  test "archive action is idempotent" do
    @event.update!(archived_at: Time.current)

    patch archive_event_path(@event), params: { return_to: events_path }

    assert_redirected_to events_url
    assert_equal "Event is already archived.", flash[:alert]
  end

  test "restore action is idempotent for active event" do
    patch restore_event_path(@event), params: { return_to: events_path }

    assert_redirected_to events_url
    assert_equal "Event is already active.", flash[:alert]
  end
end
