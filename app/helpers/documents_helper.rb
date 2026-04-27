module DocumentsHelper
  require "uri"

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

  def documents_for_entity(entity)
    event = case entity
            when Event
              entity
            when Questionnaire, Question, Payment, Approval
              entity.event
            else
              nil
            end
    return Document.none unless event

    relation = event.documents.latest.order(:title)
    packet_component_ids = packet_component_logical_ids_for_event(event)
    return relation if packet_component_ids.empty?

    relation.where.not(logical_id: packet_component_ids)
  end

  def document_group_path(event, key)
    case key.to_s
    when "packet"
      packets_event_documents_path(event)
    when "staff_upload"
      staff_uploads_event_documents_path(event)
    when "packet_docs"
      packet_docs_event_documents_path(event)
    when "client_upload"
      client_uploads_event_documents_path(event)
    else
      event_documents_path(event)
    end
  end

  def packet_component_logical_ids_for_event(event)
    @packet_component_logical_ids_by_event ||= {}
    @packet_component_logical_ids_by_event[event.id] ||= Document.packet_component_logical_ids_for_event(event)
  end

  def inline_asset_data_uri(path)
    asset_path = ActionController::Base.helpers.asset_path(path)
    return asset_path if asset_path.start_with?("data:")

    source = asset_source_bytes(path, asset_path: asset_path)

    return unless source

    blob = source.is_a?(String) ? source : source.source
    base64 = Base64.strict_encode64(blob)
    content_type = Marcel::MimeType.for(StringIO.new(blob), name: path)
    "data:#{content_type};base64,#{base64}"
  end

  def inline_font_asset_data_uri(path)
    inline_asset_data_uri(path)
  end

  def pdf_base_url
    ENV.fetch("PDF_BASE_URL", "http://localhost:3000").sub(%r{/\z}, "")
  end

  def pdf_asset_url(path)
    asset_path = ActionController::Base.helpers.asset_path(path)
    return asset_path if asset_path.start_with?("data:") || asset_path.match?(%r{\A(?:https?:)?//})

    "#{pdf_base_url}#{asset_path.start_with?("/") ? asset_path : "/#{asset_path}"}"
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

  def inline_global_asset_data_uri(asset)
    return unless asset&.content_type.to_s.start_with?("image/")
    return if asset.storage_uri.blank?

    storage = R2::Storage.new
    data = storage.download(asset.storage_uri)
    if data.present?
      buffer = data.respond_to?(:read) ? data.read : data.to_s
      buffer = buffer.to_s
      buffer.force_encoding(Encoding::BINARY)
      return "data:#{asset.content_type};base64,#{Base64.strict_encode64(buffer)}" if buffer.present?
    end

    storage.presigned_download_url(key: asset.storage_uri)
  rescue StandardError => e
    Rails.logger.warn("[inline_global_asset_data_uri] #{e.class}: #{e.message}")
    nil
  end

  private

  def asset_source_bytes(path, asset_path:)
    manifest = Rails.application.assets_manifest if Rails.application.respond_to?(:assets_manifest)
    source = manifest&.find_sources(path)&.first
    return source if source.present?

    env = Rails.application.try(:assets)
    if env.respond_to?(:resolver) && env.resolver.respond_to?(:read)
      source = env.resolver.read(path, encoding: "ASCII-8BIT")
      return source if source.present?
    end

    if env.respond_to?(:find_asset)
      asset = env.find_asset(path)
      source = asset&.source
      return source if source.present?
    end

    clean_asset_path = asset_path.sub(%r{^/}, "")
    candidate_paths = [
      Rails.root.join("app/assets/fonts", path),
      Rails.root.join("app/assets/images", path),
      Rails.root.join("app/assets/stylesheets", path),
      Rails.root.join("app/assets", path),
      Rails.root.join("public", clean_asset_path),
      Rails.root.join("public/assets", clean_asset_path),
      Rails.root.join("public/assets", File.basename(clean_asset_path))
    ]

    candidate = candidate_paths.find(&:exist?)
    candidate&.binread
  end
end
