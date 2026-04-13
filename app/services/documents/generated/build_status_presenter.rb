module Documents
  module Generated
    class BuildStatusPresenter
      def initialize(build:, status: nil, working_available: nil, rendered_at: nil, refresh_error: nil, viewer_token: nil, viewer_path: nil)
        @build = build
        @status = status
        @working_available = working_available
        @rendered_at = rendered_at
        @refresh_error = refresh_error
        @viewer_token = viewer_token
        @viewer_path = viewer_path
      end

      def as_json(*)
        payload = if build.present?
                    build.progress_payload.merge(status: status.presence || build.status)
                  else
                    { status: status.presence || "missing", build_id: nil, build_kind: nil, progress_stage: nil, progress_message: nil, progress_current: nil, progress_total: nil, last_progress_at: nil }
                  end

        payload[:working_available] = !!working_available
        payload[:rendered_at] = rendered_at&.utc&.iso8601
        payload[:refresh_error] = refresh_error
        payload[:viewer_token] = viewer_token || "missing"
        payload[:viewer_path] = viewer_path
        payload
      end

      private

      attr_reader :build, :status, :working_available, :rendered_at, :refresh_error, :viewer_token, :viewer_path
    end
  end
end
