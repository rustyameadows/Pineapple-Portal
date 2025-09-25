module DocumentsHelper
  def document_source_label(document)
    Document.source_label(document.source)
  end

  def document_visibility_label(document)
    document.client_visible? ? "Client-visible" : "Planner only"
  end

  def document_visibility_badge_class(document)
    document.client_visible? ? "documents-table__badge--client" : "documents-table__badge--internal"
  end

  def document_uploader_label(document)
    case document.source
    when "client_upload"
      "Client upload"
    when "packet"
      "Planner packet"
    else
      "Planning team"
    end
  end

  def document_updated_label(document)
    document.updated_at&.to_fs(:long) || "—"
  end

  def document_size_label(document)
    number_to_human_size(document.size_bytes)
  end

  def entity_label(entity)
    case entity
    when Event
      "Event: #{entity.name}"
    when Questionnaire
      "Questionnaire: #{entity.title}"
    when Question
      "Question: #{entity.prompt.truncate(40)}"
    else
      entity.class.name
    end
  end

  def documents_for_entity(entity)
    case entity
    when Event
      entity.documents.order(:title, :version)
    when Questionnaire, Question
      entity.event.documents.order(:title, :version)
    else
      Document.none
    end
  end

  def document_group_path(event, key)
    case key.to_s
    when "packet"
      packets_event_documents_path(event)
    when "staff_upload"
      staff_uploads_event_documents_path(event)
    when "client_upload"
      client_uploads_event_documents_path(event)
    else
      event_documents_path(event)
    end
  end
end
