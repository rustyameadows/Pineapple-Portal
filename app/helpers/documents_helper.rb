module DocumentsHelper
  SOURCE_LABELS = {
    "packet" => "Packets",
    "staff_upload" => "Planner Uploads",
    "client_upload" => "Client Uploads"
  }.freeze

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

  def document_source_label_text(key)
    SOURCE_LABELS[key.to_s] || key.to_s.humanize
  end

  def document_source_label_for(document)
    document_source_label_text(document.source)
  end

  def document_visibility_label(document)
    document.client_visible? ? "Client visible" : "Planner only"
  end

  def document_visibility_hint(document)
    document.client_visible? ? "Shared in client portal" : "Hidden from client portal"
  end

  def document_uploader_label(document)
    case document.source
    when "client_upload"
      "Client"
    else
      "Planning team"
    end
  end

  def document_version_badge(document)
    badge = tag.span("v#{document.version}", class: "documents-table__badge")
    status = if document.is_latest?
               tag.span("Latest", class: "documents-table__status documents-table__status--latest")
             else
               tag.span("Replaced", class: "documents-table__status documents-table__status--archived")
             end
    safe_join([badge, status], " ")
  end

  def document_latest_explanation(document)
    document.is_latest? ? "Current version" : "Superseded by a newer upload"
  end

  def document_updated_timestamp(document)
    l(document.updated_at, format: :long)
  end

  def document_size_label(document)
    number_to_human_size(document.size_bytes)
  end

  def document_table_header(column)
    {
      title: "Title",
      version: "Version",
      updated_at: "Updated",
      visibility: "Visibility",
      source: "Source",
      uploader: "Uploader",
      size: "File size",
      actions: "Actions"
    }[column] || column.to_s.humanize
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
