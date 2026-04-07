class DocumentsController < ApplicationController
  before_action :set_event
  before_action :set_document, only: %i[show edit update destroy download]
  before_action :load_versions, only: %i[show edit update]
  skip_before_action :require_login, only: :download
  before_action :authorize_download, only: :download

  def index
    assign_packet_component_filter_state
    @document_groups = build_document_groups
    @latest_documents = filtered_uploaded_documents(@event.documents)
    @generated_documents = generated_manifest
  end

  def packets
    render_grouped_documents(:packet)
  end

  def staff_uploads
    render_grouped_documents(:staff_upload)
  end

  def client_uploads
    render_grouped_documents(:client_upload)
  end

  def show
    @attachments = @document.attachments.includes(document: :event).order(:context, :position)
  end

  def new
    @document = @event.documents.new
    @document.logical_id = params[:logical_id] if params[:logical_id].present?
    @existing_versions = versions_for(@document.logical_id)
    @next_version_number = (@existing_versions.first&.version || 0) + 1
  end

  def create
    attrs = document_params
    @document = @event.documents.new(attrs)

    if disallowed_staff_source_selected?(@document, attrs[:source])
      @existing_versions = versions_for(@document.logical_id)
      @next_version_number = (@existing_versions.first&.version || 0) + 1
      render :new, status: :unprocessable_content
      return
    end

    if @document.save
      redirect_to event_document_path(@event, @document), notice: "Document saved."
    else
      @existing_versions = versions_for(@document.logical_id)
      @next_version_number = (@existing_versions.first&.version || 0) + 1
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    attrs = edit_document_params
    if disallowed_staff_source_selected?(@document, attrs[:source])
      render :edit, status: :unprocessable_content
      return
    end

    if @document.update(attrs)
      redirect_to safe_return_to(fallback: event_document_path(@event, @document)), notice: "Document updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @document.destroy
    redirect_to event_documents_path(@event), notice: "Document deleted."
  end

  def download
    storage = R2::Storage.new
    redirect_to storage.presigned_download_url(key: @document.storage_uri), allow_other_host: true
  end

  private

  def authorize_download
    return if current_user&.planner_or_admin?

    client_user = client_portal_user
    if client_user && client_has_event_access?(client_user)
      return
    end

    session.delete(:client_user_id) if session[:client_user_id].present? && client_user.nil?
    redirect_to client_login_path, alert: "Please sign in to view this file."
  end

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_document
    @document = @event.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :storage_uri, :checksum, :size_bytes, :content_type, :logical_id, :client_visible, :financial_portal_visible, :packets_portal_visible, :source)
  end

  def edit_document_params
    params.require(:document).permit(:title, :content_type, :client_visible, :financial_portal_visible, :packets_portal_visible, :source)
  end

  def render_grouped_documents(source_key)
    assign_packet_component_filter_state
    @source_key = source_key.to_s
    @label = Document.source_label(@source_key)
    @documents = filtered_uploaded_documents(@event.documents.where(source: @source_key))

    if @source_key == "packet"
      generated_latest = latest_compiled_generated_documents
      combined_documents = @documents.to_a + generated_latest
      @documents = combined_documents.uniq { |doc| doc.id }.sort_by { |doc| [doc.updated_at || Time.at(0), doc.title.to_s.downcase] }.reverse
    end
    @document_groups = build_document_groups
    @generated_documents = @source_key == "packet" ? generated_manifest : []
    render :group
  end

  def filtered_uploaded_documents(scope)
    relation = scope.where(doc_kind: Document::DOC_KINDS[:uploaded]).latest

    unless include_packet_component_documents?
      packet_component_ids = packet_component_logical_ids_for_event
      relation = relation.where.not(logical_id: packet_component_ids) if packet_component_ids.any?
    end

    relation.order(updated_at: :desc, title: :asc)
  end

  def build_document_groups
    Document.sources.keys.map do |key|
      scope = @event.documents.where(source: key, doc_kind: Document::DOC_KINDS[:uploaded])
      {
        key: key,
        label: Document.source_label(key),
        documents_count: scope.count,
        images_count: scope.where("content_type LIKE ?", "image/%").count
      }
    end
  end

  def load_versions
    @versions = versions_for(@document.logical_id)
  end

  def versions_for(logical_id)
    return Document.none if logical_id.blank?

    @event.documents.where(logical_id: logical_id, doc_kind: Document::DOC_KINDS[:uploaded]).order(version: :desc)
  end

  def client_portal_user
    return @client_portal_user if defined?(@client_portal_user)

    @client_portal_user = if session[:client_user_id].present?
                             User.clients.find_by(id: session[:client_user_id])
                           else
                             nil
                           end
  end

  def client_has_event_access?(user)
    user.events_as_team_member
        .where(event_team_members: {
          event_id: @event.id,
          member_role: EventTeamMember::TEAM_ROLES[:client],
          client_visible: true
        })
        .exists?
  end

  def generated_manifest
    generated_scope = @event.documents.where(doc_kind: Document::DOC_KINDS[:generated], packet_container_kind: Document::PACKET_CONTAINER_KINDS[:packet])
    grouped = generated_scope.order(:logical_id, version: :asc).group_by(&:logical_id)

    grouped.filter_map do |logical_id, records|
      definition = records.find { |record| record.definition_placeholder? }
      definition ||= records.find(&:storage_uri).presence || records.first
      next unless definition

      {
        logical_id: logical_id,
        definition: definition,
        latest_version: records.find(&:is_latest?)
      }
    end.sort_by { |entry| entry[:definition].title.to_s.downcase }
  end

  def latest_compiled_generated_documents
    generated_scope = @event.documents.where(doc_kind: Document::DOC_KINDS[:generated], packet_container_kind: Document::PACKET_CONTAINER_KINDS[:packet]).where.not(storage_uri: nil)
    grouped = generated_scope.order(version: :desc).group_by(&:logical_id)
    grouped.values.map { |versions| versions.max_by(&:version) }
  end

  def disallowed_staff_source_selected?(document, source_value)
    requested_source = source_value.to_s
    return false if requested_source.blank?
    return false unless requested_source == "client_upload"
    return false if document.persisted? && document.source == "client_upload"

    document.errors.add(:source, "client uploads can only be created from the client portal")
    true
  end

  def include_packet_component_documents?
    ActiveModel::Type::Boolean.new.cast(params[:include_packet_components])
  end

  def packet_component_logical_ids_for_event
    @packet_component_logical_ids_for_event ||= Document.packet_component_logical_ids_for_event(@event)
  end

  def assign_packet_component_filter_state
    @show_packet_component_documents = include_packet_component_documents?
    @packet_component_document_count = packet_component_logical_ids_for_event.count
  end
end
