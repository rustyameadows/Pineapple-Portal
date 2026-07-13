require "application_system_test_case"

class GeneratedPacketGroupDragTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @user = users(:one)
    @packet = create_container("Drag Packet", :packet)
    @group = create_container("Event Information", :group)

    @group.packet_placements.create!(source: create_page_source("Event Information"), position: 1)
    group_source = GeneratedPacketSource.find_or_create_group_source!(@event, @group)
    @group_placement = @packet.packet_placements.create!(source: group_source, position: 1)

    @page_source = create_page_source("Standalone Notes")
    @page_placement = @packet.packet_placements.create!(source: @page_source, position: 2)
  end

  test "drags a page into and back out of a group" do
    login_as_planner(@user)
    visit edit_event_documents_generated_path(@event, @packet.logical_id)

    drag_item_to_list(
      @page_placement.id,
      ".generated-builder__toc-children [data-generated-segments-target~='list']"
    )

    assert_selector ".generated-builder__toc-children .generated-builder__toc-item--child", text: "Standalone Notes", wait: 8
    moved_into_group = @group.packet_placements.find_by!(generated_packet_source_id: @page_source.id)
    assert_nil @packet.packet_placements.find_by(generated_packet_source_id: @page_source.id)

    drag_item_to_list(
      moved_into_group.id,
      ".generated-builder__segments:not(.generated-builder__segments--nested) > .generated-builder__toc > [data-generated-segments-target~='list']"
    )

    assert_selector ".generated-builder__toc-body > .generated-builder__toc-item", text: "Standalone Notes", wait: 8
    assert @packet.packet_placements.find_by!(generated_packet_source_id: @page_source.id)
    assert_nil @group.packet_placements.find_by(generated_packet_source_id: @page_source.id)
  end

  private

  def create_container(title, kind)
    @event.documents.create!(
      title: title,
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      client_visible: false,
      source: "packet",
      built_by_user: @user,
      packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
      packet_container_kind: Document::PACKET_CONTAINER_KINDS.fetch(kind)
    )
  end

  def create_page_source(title)
    GeneratedPacketSource.build_page_source(
      event: @event,
      view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
      title: title,
      options: { "body_markdown" => title }
    ).tap(&:save!)
  end

  def drag_item_to_list(placement_id, target_selector)
    assert_selector "[data-segment-id='#{placement_id}'] .generated-builder__drag-handle"
    assert_selector target_selector

    page.execute_script(<<~JAVASCRIPT)
      (() => {
        const item = document.querySelector('[data-segment-id="#{placement_id}"]')
        const handle = item.querySelector('.generated-builder__drag-handle')
        const target = document.querySelector(#{target_selector.to_json})
        const transfer = new DataTransfer()
        const rect = target.getBoundingClientRect()

        handle.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))
        item.dispatchEvent(new DragEvent('dragstart', { bubbles: true, dataTransfer: transfer }))
        target.dispatchEvent(new DragEvent('dragover', {
          bubbles: true,
          cancelable: true,
          clientY: rect.bottom - 2,
          dataTransfer: transfer
        }))
        target.dispatchEvent(new DragEvent('drop', {
          bubbles: true,
          cancelable: true,
          clientY: rect.bottom - 2,
          dataTransfer: transfer
        }))
      })()
    JAVASCRIPT
  end
end
