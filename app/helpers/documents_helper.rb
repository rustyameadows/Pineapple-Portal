module DocumentsHelper
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
