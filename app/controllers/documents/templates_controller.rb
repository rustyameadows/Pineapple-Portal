require "ostruct"

module Documents
  class TemplatesController < ApplicationController
    before_action :set_event

    def index
      @document_title = default_document_title
      @templates = DocumentSegment::HTML_VIEWS.map do |key, config|
        {
          key: key,
          config: config,
          preview_html: render_preview(config[:template], key)
        }
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def default_document_title
      [@event.name, "Packet"].compact.join(" ")
    end

    def render_preview(template_path, key)
      segment = OpenStruct.new(
        document: OpenStruct.new(title: default_document_title),
        source_ref: { "view_key" => key }
      )

      html = ApplicationController.renderer.render(
        template: template_path,
        layout: false,
        assigns: {
          event: @event,
          segment: segment
        }
      )

      ApplicationController.helpers.content_tag(
        :div,
        html.html_safe,
        class: "document-template document-template--preview"
      )
    rescue StandardError => e
      ApplicationController.helpers.content_tag(
        :p,
        "Preview unavailable: #{e.message}",
        class: "template-card__error"
      )
    end
  end
end
