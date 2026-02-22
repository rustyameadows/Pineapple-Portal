require "test_helper"

module Events
  class ApprovalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "clear_response clears client name and note without changing status or responded timestamp" do
      approval = @event.approvals.create!(
        title: "Menu Signoff",
        summary: "Please review",
        client_visible: true,
        status: :approved,
        acknowledged_at: 2.days.ago,
        client_name: "Adam Client",
        client_note: "Looks good with one update."
      )

      original_status = approval.status
      original_responded_at = approval.acknowledged_at

      patch clear_response_event_approval_url(@event, approval)

      assert_redirected_to event_approval_url(@event, approval)
      follow_redirect!
      assert_match "Client response cleared.", response.body

      approval.reload
      assert_nil approval.client_name
      assert_nil approval.client_note
      assert_equal original_status, approval.status
      assert_equal original_responded_at.to_i, approval.acknowledged_at.to_i
    end

    test "clear_response keeps pending status when clearing manual response fields" do
      approval = @event.approvals.create!(
        title: "Timeline Review",
        summary: "Planner reset this and wants to clear old response",
        client_visible: true,
        status: :pending,
        acknowledged_at: 1.day.ago,
        client_name: "Legacy Name",
        client_note: "Legacy note"
      )

      patch clear_response_event_approval_url(@event, approval)

      assert_redirected_to event_approval_url(@event, approval)
      approval.reload
      assert approval.pending?
      assert_nil approval.client_name
      assert_nil approval.client_note
      assert_not_nil approval.acknowledged_at
    end

    test "show renders clear response button when response data exists" do
      approval = @event.approvals.create!(
        title: "Floral Design",
        client_visible: true,
        status: :acknowledged,
        acknowledged_at: Time.current,
        client_name: "Adam",
        client_note: "Please adjust centerpieces."
      )

      get event_approval_url(@event, approval)

      assert_response :success
      assert_select "button", text: "Clear response", count: 1
    end

    test "show hides clear response button when no response data exists" do
      approval = @event.approvals.create!(
        title: "Seating Chart",
        client_visible: true,
        status: :approved,
        acknowledged_at: Time.current,
        client_name: nil,
        client_note: nil
      )

      get event_approval_url(@event, approval)

      assert_response :success
      assert_select "button", text: "Clear response", count: 0
    end
  end
end
