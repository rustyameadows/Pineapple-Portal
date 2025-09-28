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

  def inline_asset_data_uri(path)
    asset_path = ActionController::Base.helpers.asset_path(path)
    return asset_path if asset_path.start_with?("data:")

    manifest = Rails.application.assets_manifest if Rails.application.respond_to?(:assets_manifest)
    source = manifest&.find_sources(path)&.first
    if source.nil?
      env = Rails.application.try(:assets)
      if env.respond_to?(:find_asset)
        asset = env.find_asset(path)
        source = asset&.source
      end
    end

    if source.nil?
      clean_asset_path = asset_path.sub(%r{^/}, "")
      candidate_paths = [
        Rails.root.join("app/assets/images", path),
        Rails.root.join("app/assets", path),
        Rails.root.join("public", clean_asset_path),
        Rails.root.join("public/assets", clean_asset_path),
        Rails.root.join("public/assets", File.basename(clean_asset_path))
      ]

      candidate = candidate_paths.find { |p| p.exist? }
      source = candidate&.binread if candidate
    end

    return unless source

    blob = source.is_a?(String) ? source : source.source
    base64 = Base64.strict_encode64(blob)
    content_type = Marcel::MimeType.for(StringIO.new(blob), name: path)
    "data:#{content_type};base64,#{base64}"
  end

  def inline_document_image_data_uri(document)
    return unless document&.content_type.to_s.start_with?("image/")
    return if document.storage_uri.blank?

    storage = R2::Storage.new
    data = storage.download(document.storage_uri)
    if data.present?
      buffer = data.respond_to?(:read) ? data.read : data.to_s
      buffer = buffer.to_s
      buffer.force_encoding(Encoding::BINARY)
      return "data:#{document.content_type};base64,#{Base64.strict_encode64(buffer)}" if buffer.present?
    end

    storage.presigned_download_url(key: document.storage_uri)
  rescue StandardError => e
    Rails.logger.warn("[inline_document_image_data_uri] #{e.class}: #{e.message}")
    nil
  end
end
