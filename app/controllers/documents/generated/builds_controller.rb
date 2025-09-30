module Documents
  module Generated
    class BuildsController < ApplicationController
      before_action :set_event
      before_action :set_document
      before_action :set_build

      def cancel
        if @build.cancelable?
          @build.mark_cancelled!
          redirect_to builder_path, notice: "Build cancelled."
        else
          redirect_to builder_path, alert: "Build is already finished."
        end
      rescue StandardError => e
        redirect_to builder_path, alert: "Unable to cancel build: #{e.message}"
      end

      def destroy
        if @build.running?
          redirect_to builder_path, alert: "Stop the build before deleting it."
          return
        end

        @build.destroy
        redirect_to builder_path, notice: "Build removed."
      rescue StandardError => e
        redirect_to builder_path, alert: "Unable to remove build: #{e.message}"
      end

      private

      def set_event
        @event = Event.find(params[:event_id])
      end

      def set_document
        logical_id = params[:logical_id] || params[:generated_id] || params[:generated_logical_id]
        scope = @event.documents.where(doc_kind: Document::DOC_KINDS[:generated], logical_id: logical_id)
        @document = scope.find_by(storage_uri: nil) || scope.order(version: :asc).first
        raise ActiveRecord::RecordNotFound unless @document
      end

      def set_build
        @build = @document.builds.find(params[:id])
      end

      def builder_path
        event_documents_generated_path(@event, @document.logical_id)
      end
    end
  end
end
