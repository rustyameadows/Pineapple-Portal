require "test_helper"

module Client
  class ApprovalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @client = users(:client_contact)
      log_in_client_portal(@client)
    end

    test "index shows only client-visible approvals with pending first" do
      pending_approval = @event.approvals.create!(
        title: "Catering Menu",
        summary: "Please confirm final menu.",
        client_visible: true,
        status: :pending
      )
      returned_approval = @event.approvals.create!(
        title: "Floor Plan",
        summary: "Returned with edits.",
        client_visible: true,
        status: :acknowledged,
        acknowledged_at: 1.day.ago
      )
      approved_approval = @event.approvals.create!(
        title: "Venue Contract",
        summary: "Approved contract.",
        client_visible: true,
        status: :approved,
        acknowledged_at: 2.days.ago
      )
      @event.approvals.create!(
        title: "Hidden Approval",
        summary: "Internal only.",
        client_visible: false,
        status: :pending
      )

      get client_event_approvals_url(@event)

      assert_response :success
      assert_select "h1", text: "Approvals"
      assert_select "td", text: pending_approval.title
      assert_select "td", text: returned_approval.title
      assert_select "td", text: approved_approval.title
      assert_select ".client-pill", text: "Returned with comments"
      assert_select ".client-pill", text: "Approved"
      assert_select "td", text: "Hidden Approval", count: 0
      assert_operator response.body.index(pending_approval.title), :<, response.body.index(returned_approval.title)
      assert_operator response.body.index(pending_approval.title), :<, response.body.index(approved_approval.title)
    end

    test "index renders empty state when no approvals are visible" do
      get client_event_approvals_url(@event)

      assert_response :success
      assert_select ".client-placeholder", text: /No approvals have been published yet\./
    end

    test "show renders approval content with pending actions" do
      approval = @event.approvals.create!(
        title: "Lighting Cue Sheet",
        summary: "Review the updated cue list.",
        instructions: "Confirm by tomorrow at 5 PM.",
        client_visible: true,
        status: :pending
      )
      approval.attachments.create!(
        document: documents(:contract_v1),
        context: "other",
        position: 1
      )

      get client_event_approval_url(@event, approval)

      assert_response :success
      assert_select "h1", text: approval.title
      assert_select "button", text: "Approve"
      assert_select "textarea[name='approval[client_note]'][required]", count: 1
      assert_select "a", text: "Production Contract"
    end

    test "show hides pending actions for returned approval" do
      approval = @event.approvals.create!(
        title: "Vendor Selection",
        summary: "Client approved preferred vendor.",
        client_visible: true,
        status: :acknowledged,
        acknowledged_at: Time.current,
        client_name: "Taylor Client",
        client_note: "Looks great."
      )

      get client_event_approval_url(@event, approval)

      assert_response :success
      assert_select "button", text: "Approve", count: 0
      assert_select "textarea[name='approval[client_note]']", count: 0
      assert_select "h2", text: "Client response"
      assert_select ".client-pill", text: "Returned with comments"
    end

    test "show renders approved approval without responded timestamp" do
      approval = @event.approvals.create!(
        title: "Final Layout",
        summary: "Marked approved from imported data.",
        client_visible: true,
        status: :approved,
        acknowledged_at: nil
      )

      get client_event_approval_url(@event, approval)

      assert_response :success
      assert_select "h1", text: approval.title
      assert_select "p", text: "Approved"
    end

    test "show renders returned approval without responded timestamp" do
      approval = @event.approvals.create!(
        title: "Audio Notes",
        summary: "Marked returned from imported data.",
        client_visible: true,
        status: :acknowledged,
        acknowledged_at: nil
      )

      get client_event_approval_url(@event, approval)

      assert_response :success
      assert_select "h1", text: approval.title
      assert_select "p", text: "Returned with comments"
    end

    test "accept approves pending approval" do
      approval = @event.approvals.create!(
        title: "Band Contract",
        summary: "Please confirm the final version.",
        client_visible: true,
        status: :pending
      )

      patch accept_client_event_approval_url(@event, approval)

      assert_redirected_to client_event_approval_url(@event.portal_slug, approval)
      approval.reload
      assert approval.approved?
      assert_not_nil approval.acknowledged_at
      assert_equal @client.name, approval.client_name
    end

    test "respond returns pending approval with comments and stores comment" do
      approval = @event.approvals.create!(
        title: "Ceremony Timeline",
        summary: "Please review flow.",
        client_visible: true,
        status: :pending
      )

      patch respond_client_event_approval_url(@event, approval), params: {
        approval: { client_note: "Approved with one minor update." }
      }

      assert_redirected_to client_event_approval_url(@event.portal_slug, approval)
      approval.reload
      assert approval.acknowledged?
      assert_equal "Approved with one minor update.", approval.client_note
      assert_equal @client.name, approval.client_name
    end

    test "accept on approved approval leaves status unchanged with status-specific notice" do
      approval = @event.approvals.create!(
        title: "Approved Plan",
        summary: "Already approved.",
        client_visible: true,
        status: :approved,
        acknowledged_at: 1.day.ago
      )

      patch accept_client_event_approval_url(@event, approval)

      assert_redirected_to client_event_approval_url(@event.portal_slug, approval)
      follow_redirect!
      assert_match "Approval already approved.", response.body
      approval.reload
      assert approval.approved?
    end

    test "accept on returned approval leaves status unchanged with status-specific notice" do
      approval = @event.approvals.create!(
        title: "Returned Plan",
        summary: "Already returned.",
        client_visible: true,
        status: :acknowledged,
        acknowledged_at: 1.day.ago,
        client_note: "Needs edits."
      )

      patch accept_client_event_approval_url(@event, approval)

      assert_redirected_to client_event_approval_url(@event.portal_slug, approval)
      follow_redirect!
      assert_match "Approval already returned with comments.", response.body
      approval.reload
      assert approval.acknowledged?
    end

    test "respond on non-pending approval leaves status unchanged with status-specific notice" do
      approval = @event.approvals.create!(
        title: "Approved Timeline",
        summary: "Already approved.",
        client_visible: true,
        status: :approved,
        acknowledged_at: 1.day.ago
      )

      patch respond_client_event_approval_url(@event, approval), params: {
        approval: { client_note: "Need a tweak." }
      }

      assert_redirected_to client_event_approval_url(@event.portal_slug, approval)
      follow_redirect!
      assert_match "Approval already approved.", response.body
      approval.reload
      assert approval.approved?
      assert_nil approval.client_note
    end

    test "respond rejects blank comments and keeps approval pending" do
      approval = @event.approvals.create!(
        title: "Reception Layout",
        summary: "Need final client confirmation.",
        client_visible: true,
        status: :pending
      )

      patch respond_client_event_approval_url(@event, approval), params: {
        approval: { client_note: "   " }
      }

      assert_redirected_to client_event_approval_url(@event.portal_slug, approval)
      approval.reload
      assert approval.pending?
      assert_nil approval.acknowledged_at
      assert_nil approval.client_note
    end
  end
end
