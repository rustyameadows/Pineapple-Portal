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
end
