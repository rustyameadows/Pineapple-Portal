module Client
  class ApprovalsController < PortalController
    before_action :set_approval, only: %i[show accept respond]

    def index
      status_priority = Arel.sql("CASE approvals.status WHEN 'pending' THEN 0 ELSE 1 END")
      @approvals = @event.approvals
                         .client_visible
                         .order(status_priority, updated_at: :desc, title: :asc)
    end

    def show
      @attachments = @approval.attachments.includes(document: :event)
    end

    def accept
      notice = if @approval.pending?
                 @approval.approve!(name: responder_name)
                 "Approval accepted."
               else
                 already_responded_notice
               end

      redirect_to client_event_approval_path(event_key, @approval), notice: notice
    rescue ActiveRecord::RecordInvalid => e
      redirect_to client_event_approval_path(event_key, @approval), alert: e.record.errors.full_messages.to_sentence
    end

    def respond
      note = approval_params[:client_note].to_s.strip
      if note.blank?
        redirect_to client_event_approval_path(event_key, @approval), alert: "Comments are required to respond."
        return
      end

      notice = if @approval.pending?
                 @approval.return_with_comments!(name: responder_name, note: note)
                 "Response recorded."
               else
                 already_responded_notice
               end

      redirect_to client_event_approval_path(event_key, @approval), notice: notice
    rescue ActiveRecord::RecordInvalid => e
      redirect_to client_event_approval_path(event_key, @approval), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_approval
      @approval = @event.approvals.client_visible.find(params[:id])
    end

    def approval_params
      params.fetch(:approval, {}).permit(:client_note)
    end

    def responder_name
      current_client_user&.name.presence || portal_current_user&.name.presence
    end

    def event_key
      @event.portal_slug.presence || @event.id
    end

    def already_responded_notice
      if @approval.approved?
        "Approval already approved."
      elsif @approval.acknowledged?
        "Approval already returned with comments."
      else
        "Approval already responded to."
      end
    end
  end
end
