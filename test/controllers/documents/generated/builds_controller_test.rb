require "test_helper"

module Documents
  module Generated
    class BuildsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @event = events(:one)
        @user = users(:one)
        log_in_as(@user)

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
          build_kind: DocumentBuild::BUILD_KINDS[:snapshot],
          build_id: SecureRandom.uuid,
          progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
          progress_message: "Rendering pages 2/5",
          progress_current: 2,
          progress_total: 5,
          last_progress_at: Time.current
        )
      end

      test "status returns the toast progress payload" do
        get status_event_documents_generated_build_url(@event, @document.logical_id, @build)

        assert_response :success
        assert_equal "application/json", response.media_type

        payload = JSON.parse(response.body)
        assert_equal @build.build_id, payload["build_id"]
        assert_equal DocumentBuild::BUILD_KINDS[:snapshot], payload["build_kind"]
        assert_equal DocumentBuild::STATUSES[:running], payload["status"]
        assert_equal DocumentBuild::PROGRESS_STAGES[:rendering_entries], payload["progress_stage"]
        assert_equal "Rendering pages 2/5", payload["progress_message"]
        assert_equal 2, payload["progress_current"]
        assert_equal 5, payload["progress_total"]
        assert payload["last_progress_at"].present?
      end
    end
  end
end
