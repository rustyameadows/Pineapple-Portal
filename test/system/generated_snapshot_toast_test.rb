require "application_system_test_case"

class GeneratedSnapshotToastTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @user = users(:one)

    @document = @event.documents.create!(
      title: "Generated Packet",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      client_visible: false,
      source: "packet",
      built_by_user: @user,
      packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
    )

    @build = @document.builds.create!(
      status: DocumentBuild::STATUSES[:running],
      build_id: SecureRandom.uuid,
      progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
      progress_message: "Rendering pages 1/3",
      progress_current: 1,
      progress_total: 3,
      last_progress_at: Time.current
    )
  end

  test "active snapshot toast updates from polling" do
    login_as_planner
    visit event_documents_generated_path(@event, @document.logical_id)

    assert_selector ".flash-toast--build .flash-toast__text", text: "Rendering pages 1/3"

    @build.report_progress!(
      stage: :rendering_entries,
      current: 2,
      total: 3
    )

    assert_selector ".flash-toast--build .flash-toast__text", text: "Rendering pages 2/3", wait: 6
  end

  private

  def login_as_planner
    visit login_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Log In"
    assert_text "Your Active Events"
  end
end
