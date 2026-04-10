require "test_helper"

class DocumentBuildTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
    @document = @event.documents.create!(
      title: "Generated Packet",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      client_visible: false,
      source: "packet",
      built_by_user: users(:one),
      packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
    )
  end

  test "report_progress updates stage details and last_progress_at" do
    build = @document.builds.create!(
      status: DocumentBuild::STATUSES[:pending],
      build_id: SecureRandom.uuid
    )

    freeze_time do
      build.report_progress!(
        stage: :rendering_entries,
        current: 3,
        total: 8
      )
    end

    build.reload
    assert_equal DocumentBuild::PROGRESS_STAGES[:rendering_entries], build.progress_stage
    assert_equal "Rendering pages 3/8", build.progress_message
    assert_equal 3, build.progress_current
    assert_equal 8, build.progress_total
    assert_equal Time.current.to_i, build.last_progress_at.to_i
  end

  test "display_progress_message falls back to stage defaults" do
    build = @document.builds.create!(
      status: DocumentBuild::STATUSES[:running],
      build_id: SecureRandom.uuid,
      progress_stage: DocumentBuild::PROGRESS_STAGES[:assembling_pdf]
    )

    assert_equal "Assembling PDF", build.display_progress_message
  end

  test "active? is true only for pending and running builds" do
    pending_build = @document.builds.create!(status: DocumentBuild::STATUSES[:pending], build_id: SecureRandom.uuid)
    running_build = @document.builds.create!(status: DocumentBuild::STATUSES[:running], build_id: SecureRandom.uuid)
    succeeded_build = @document.builds.create!(status: DocumentBuild::STATUSES[:succeeded], build_id: SecureRandom.uuid)

    assert pending_build.active?
    assert running_build.active?
    assert_not succeeded_build.active?
  end

  test "builds default to snapshot and can be scoped by kind" do
    snapshot_build = @document.builds.create!(status: DocumentBuild::STATUSES[:pending])
    working_build = @document.builds.create!(
      status: DocumentBuild::STATUSES[:pending],
      build_kind: DocumentBuild::BUILD_KINDS[:working],
      page_numbers: true
    )

    assert_equal DocumentBuild::BUILD_KINDS[:snapshot], snapshot_build.build_kind
    assert_includes @document.snapshot_builds, snapshot_build
    assert_includes @document.working_builds, working_build
  end
end
