require "test_helper"

module Documents
  module Generated
    class SegmentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @event = events(:one)
        @user = users(:one)
        log_in_as(@user)

        @document = @event.documents.create!(
          title: "Generated Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )

        @placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
            title: "Text Page",
            options: { "body_markdown" => "Initial content" }
          ).tap(&:save!),
          position: 1
        )
      end

      test "creates text page packet page with normalized markdown option" do
        enqueued_logical_ids = []

        assert_difference("GeneratedPacketSource.count", 1) do
          assert_difference("GeneratedPacketPlacement.count", 1) do
            Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
              post event_documents_generated_segments_url(@event, @document.logical_id), params: {
                segment: {
                  view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
                  title: "General Notes",
                  options: {
                    body_markdown: "Line 1\r\nLine 2",
                    ignored_key: "ignore me"
                  }
                }
              }
            end
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        created = GeneratedPacketSource.order(:id).last

        assert_equal DocumentSegment::TEXT_PAGE_VIEW_KEY, created.html_view_key
        assert_equal({ "body_markdown" => "Line 1\nLine 2" }, created.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "create redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          post event_documents_generated_segments_url(@event, @document.logical_id), params: {
            return_to: return_to,
            segment: {
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              title: "General Notes",
              options: {
                body_markdown: "Line 1"
              }
            }
          }
        end

        assert_redirected_to return_to
      end

      test "create failure redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        post event_documents_generated_segments_url(@event, @document.logical_id), params: {
          return_to: return_to,
          segment: {
            view_key: "",
            title: "Broken Page"
          }
        }

        assert_redirected_to return_to
      end

      test "creates a placement for a custom timeline canonical source" do
        view = event_calendar_views(:vendor_view)
        GeneratedPacketSource.ensure_canonical_sources_for_event!(@event)
        source = @event.generated_packet_sources.find_by!(
          canonical_key: GeneratedPacketSource.custom_timeline_canonical_key(view)
        )
        enqueued_logical_ids = []

        assert_no_difference("GeneratedPacketSource.count") do
          assert_difference("GeneratedPacketPlacement.count", 1) do
            Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
              post event_documents_generated_segments_url(@event, @document.logical_id), params: {
                segment: {
                  source_id: source.id
                }
              }
            end
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        placement = GeneratedPacketPlacement.order(:id).last
        assert_equal source, placement.source
        assert_equal DocumentSegment::TIMELINE_VIEW_KEY, placement.source.html_view_key
        assert_equal view.id.to_s, placement.source.html_options["view_ref"]
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "updates text page packet page and drops unknown option keys" do
        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            segment: {
              title: "General Notes Updated",
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              options: {
                body_markdown: "Updated\rnotes",
                extra: "remove me"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        @placement.reload

        assert_equal "General Notes Updated", @placement.source.title
        assert_equal({ "body_markdown" => "Updated\nnotes" }, @placement.source.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "update redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            return_to: return_to,
            segment: {
              title: "General Notes Updated",
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              options: {
                body_markdown: "Updated notes"
              }
            }
          }
        end

        assert_redirected_to return_to
      end

      test "destroy redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          delete event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            return_to: return_to
          }
        end

        assert_redirected_to return_to
      end

      test "updates event overview packet page without persisting markdown options" do
        overview_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
            title: "Event Overview",
            options: {}
          ).tap(&:save!),
          position: 2
        )

        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, overview_placement), params: {
            segment: {
              title: "Event Overview Updated",
              view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
              options: {
                body_markdown: "ignore this",
                extra: "ignore this too"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        overview_placement.reload

        assert_equal "Event Overview Updated", overview_placement.source.title
        assert_equal({}, overview_placement.source.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "updates wedding party reference packet page with sanitized timeline options" do
        reference_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
            title: "Wedding Party Reference",
            options: {}
          ).tap(&:save!),
          position: 3
        )

        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, reference_placement), params: {
            segment: {
              title: "Wedding Party Reference Updated",
              view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
              options: {
                timeline_mode: "manual",
                timeline_tag_ids: [
                  event_calendar_tags(:vendor).id,
                  event_calendar_tags(:wedding_party_side_a).id,
                  "",
                  999_999
                ],
                extra: "ignore this too"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        reference_placement.reload

        assert_equal "Wedding Party Reference Updated", reference_placement.source.title
        assert_equal(
          {
            "timeline_mode" => "manual",
            "timeline_tag_ids" => [
              event_calendar_tags(:vendor).id,
              event_calendar_tags(:wedding_party_side_a).id
            ]
          },
          reference_placement.source.html_options
        )
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "wedding party reference manual mode falls back to auto when no valid tags remain" do
        reference_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
            title: "Wedding Party Reference",
            options: {}
          ).tap(&:save!),
          position: 3
        )

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch event_documents_generated_segment_url(@event, @document.logical_id, reference_placement), params: {
            segment: {
              title: "Wedding Party Reference Updated",
              view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
              options: {
                timeline_mode: "manual",
                timeline_tag_ids: [999_999]
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        reference_placement.reload

        assert_equal(
          {
            "timeline_mode" => "auto",
            "timeline_tag_ids" => []
          },
          reference_placement.source.html_options
        )
      end

      test "updates vendor contacts packet page without persisting markdown options" do
        vendor_contacts_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
            title: "Vendor Contacts",
            options: {}
          ).tap(&:save!),
          position: 4
        )

        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, vendor_contacts_placement), params: {
            segment: {
              title: "Vendor Contacts Updated",
              view_key: DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
              options: {
                body_markdown: "ignore this",
                extra: "ignore this too"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        vendor_contacts_placement.reload

        assert_equal "Vendor Contacts Updated", vendor_contacts_placement.source.title
        assert_equal({}, vendor_contacts_placement.source.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "creates a shared group and inserts it into the packet" do
        enqueued_logical_ids = []

        assert_difference("Document.generated.group_containers.count", 1) do
          assert_difference("GeneratedPacketSource.group_sources.count", 1) do
            assert_difference("GeneratedPacketPlacement.count", 2) do
              Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
                post event_documents_generated_segments_url(@event, @document.logical_id), params: {
                  segment: {
                    group_title: "Design & Decor"
                  }
                }
              end
            end
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        placement = GeneratedPacketPlacement.order(:id).last

        assert placement.source.group?
        assert_equal "Design & Decor", placement.source.group_document.title
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "updating a group title syncs the shared group document" do
        group_document = @event.documents.create!(
          title: "Design & Decor",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
        )
        group_document.packet_placements.create!(
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: "section_break",
            title: "Design & Decor",
            options: {}
          ).tap(&:save!),
          position: 1
        )
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: group_source,
          position: 2
        )

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch event_documents_generated_segment_url(@event, @document.logical_id, group_placement), params: {
            segment: {
              title: "Decor Vision"
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        assert_equal "Decor Vision", group_document.reload.title
        assert_equal "Decor Vision", group_source.reload.display_title
      end

      test "queues a force build for a cached system page and returns to packet settings" do
        @placement.source.update!(
          render_hash: "cached-hash",
          cached_pdf_key: "segments/cached.pdf",
          cached_pdf_generated_at: Time.current,
          cached_page_count: 1,
          cached_file_size: 128
        )
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)
        result = Struct.new(:consumer_count).new(2)
        service = Struct.new(:result) do
          def call
            result
          end
        end.new(result)
        seen_sources = []

        Documents::Generated::ForceSourceRebuild.stub :new, ->(source:) {
          seen_sources << source
          service
        } do
          post force_build_event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            return_to: return_to
          }
        end

        assert_redirected_to return_to
        assert_equal [ @placement.source ], seen_sources
        assert_equal "Force build queued for 2 packets.", flash[:notice]
      end

      test "reports an ineligible force build without mutating the placement" do
        Documents::Generated::ForceSourceRebuild.stub :new, ->(source:) {
          Struct.new(:source) do
            def call
              raise Documents::Generated::ForceSourceRebuild::Error, "Only cached pages can be force built."
            end
          end.new(source)
        } do
          post force_build_event_documents_generated_segment_url(@event, @document.logical_id, @placement)
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        assert_equal "Only cached pages can be force built.", flash[:alert]
        assert GeneratedPacketPlacement.exists?(@placement.id)
      end

      test "moves a packet page into an existing group" do
        group_document = create_group_document(title: "Design & Decor")
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: group_source,
          position: 2
        )
        moved_source = @placement.source
        enqueued_logical_ids = []

        assert_difference("GeneratedPacketPlacement.where(document_logical_id: @document.logical_id).count", -1) do
          assert_difference("GeneratedPacketPlacement.where(document_logical_id: group_document.logical_id).count", 1) do
            Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
              patch move_to_group_event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
                target_group_placement_id: group_placement.id
              }
            end
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        assert_nil GeneratedPacketPlacement.find_by(id: @placement.id)
        assert_equal moved_source, group_document.packet_placements.ordered.last.source
        assert_equal [1], GeneratedPacketPlacement.where(document_logical_id: @document.logical_id).ordered.pluck(:position)
        assert_equal [@document.logical_id], enqueued_logical_ids.uniq
      end

      test "moves a group page out to the parent packet after the group row" do
        group_document = create_group_document(title: "Design & Decor")
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: group_source,
          position: 2
        )
        moved_source = create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Floral Proposal",
          options: { "body_markdown" => "Flowers" }
        )
        child_placement = group_document.packet_placements.create!(
          source: moved_source,
          position: 2
        )
        enqueued_logical_ids = []

        assert_difference("GeneratedPacketPlacement.where(document_logical_id: group_document.logical_id).count", -1) do
          assert_difference("GeneratedPacketPlacement.where(document_logical_id: @document.logical_id).count", 1) do
            Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
              patch move_out_of_group_event_documents_generated_segment_url(@event, group_document.logical_id, child_placement), params: {
                packet_logical_id: @document.logical_id,
                group_placement_id: group_placement.id
              }
            end
          end
        end

        assert_redirected_to edit_event_documents_generated_url(@event, group_document.logical_id)
        assert_nil GeneratedPacketPlacement.find_by(id: child_placement.id)
        assert_equal [@placement.source, group_source, moved_source], @document.packet_placements.ordered.map(&:source)
        assert_equal [1, 2, 3], @document.packet_placements.ordered.pluck(:position)
        assert_equal [1], group_document.packet_placements.ordered.pluck(:position)
        assert_equal [@document.logical_id], enqueued_logical_ids.uniq
      end

      test "relocates a packet page into an exact group position" do
        group_document = create_group_document(title: "Design & Decor")
        trailing_source = create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Trailing Group Page",
          options: { "body_markdown" => "Trailing" }
        )
        group_document.packet_placements.create!(source: trailing_source, position: 2)
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        @document.packet_placements.create!(source: group_source, position: 2)
        moved_source = @placement.source
        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) {
          enqueued_logical_ids << document.logical_id
          true
        } do
          patch relocate_event_documents_generated_segments_url(@event, @document.logical_id), params: {
            segment_id: @placement.id,
            source_container_logical_id: @document.logical_id,
            target_container_logical_id: group_document.logical_id,
            target_position: 2,
            packet_logical_id: @document.logical_id
          }
        end

        assert_response :success
        assert_nil GeneratedPacketPlacement.find_by(id: @placement.id)
        assert_equal [ "Design & Decor", "Text Page", "Trailing Group Page" ], group_document.packet_placements.ordered.map(&:title)
        assert_equal moved_source, group_document.packet_placements.ordered.second.source
        assert_equal [ 1, 2, 3 ], group_document.packet_placements.ordered.pluck(:position)
        assert_equal [ @document.logical_id ], enqueued_logical_ids.uniq
      end

      test "relocates a group page to an exact packet position" do
        group_document = create_group_document(title: "Design & Decor")
        moved_source = create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Floral Proposal",
          options: { "body_markdown" => "Flowers" }
        )
        child_placement = group_document.packet_placements.create!(source: moved_source, position: 2)
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        @document.packet_placements.create!(source: group_source, position: 2)
        tail_source = create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Packet Tail",
          options: { "body_markdown" => "Tail" }
        )
        @document.packet_placements.create!(source: tail_source, position: 3)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch relocate_event_documents_generated_segments_url(@event, @document.logical_id), params: {
            segment_id: child_placement.id,
            source_container_logical_id: group_document.logical_id,
            target_container_logical_id: @document.logical_id,
            target_position: 2,
            packet_logical_id: @document.logical_id
          }
        end

        assert_response :success
        assert_nil GeneratedPacketPlacement.find_by(id: child_placement.id)
        assert_equal [ "Text Page", "Floral Proposal", "Design & Decor", "Packet Tail" ], @document.packet_placements.ordered.map(&:title)
        assert_equal [ 1, 2, 3, 4 ], @document.packet_placements.ordered.pluck(:position)
        assert_equal [ "Design & Decor" ], group_document.packet_placements.ordered.map(&:title)
      end

      test "relocates a page directly between groups in the same packet" do
        source_group = create_group_document(title: "Event Information")
        moved_source = create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Contacts",
          options: { "body_markdown" => "Contacts" }
        )
        child_placement = source_group.packet_placements.create!(source: moved_source, position: 2)
        target_group = create_group_document(title: "Design & Decor")
        target_tail = create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Floral Proposal",
          options: { "body_markdown" => "Flowers" }
        )
        target_group.packet_placements.create!(source: target_tail, position: 2)
        @document.packet_placements.create!(
          source: GeneratedPacketSource.find_or_create_group_source!(@event, source_group),
          position: 2
        )
        @document.packet_placements.create!(
          source: GeneratedPacketSource.find_or_create_group_source!(@event, target_group),
          position: 3
        )

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch relocate_event_documents_generated_segments_url(@event, @document.logical_id), params: {
            segment_id: child_placement.id,
            source_container_logical_id: source_group.logical_id,
            target_container_logical_id: target_group.logical_id,
            target_position: 2,
            packet_logical_id: @document.logical_id
          }
        end

        assert_response :success
        assert_equal [ "Event Information" ], source_group.packet_placements.ordered.map(&:title)
        assert_equal [ "Design & Decor", "Contacts", "Floral Proposal" ], target_group.packet_placements.ordered.map(&:title)
        assert_equal [ 1, 2, 3 ], target_group.packet_placements.ordered.pluck(:position)
      end

      test "rejects relocating a group into another group" do
        group_document = create_group_document(title: "Design & Decor")
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = @document.packet_placements.create!(source: group_source, position: 2)

        assert_no_difference("GeneratedPacketPlacement.count") do
          patch relocate_event_documents_generated_segments_url(@event, @document.logical_id), params: {
            segment_id: group_placement.id,
            source_container_logical_id: @document.logical_id,
            target_container_logical_id: group_document.logical_id,
            target_position: 1,
            packet_logical_id: @document.logical_id
          }
        end

        assert_response :unprocessable_entity
        assert_equal group_source, group_placement.reload.source
        assert_equal @document.logical_id, group_placement.document_logical_id
      end

      test "previewing a group keeps the generated pdf unnumbered" do
        group_document = create_group_document(title: "Design & Decor")
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: group_source,
          position: 2
        )

        seen_kwargs = nil
        bundle_result = Struct.new(:pdf_data).new("PDF_BYTES")
        bundle_double = Struct.new(:result) do
          def call
            result
          end
        end.new(bundle_result)

        Documents::Generated::PacketBundle.stub :new, ->(**kwargs) {
          seen_kwargs = kwargs
          bundle_double
        } do
          get preview_event_documents_generated_segment_url(@event, @document.logical_id, group_placement)
        end

        assert_response :success
        assert_equal group_document, seen_kwargs[:definition_document]
        assert_equal false, seen_kwargs[:page_numbers]
      end

    private

    def create_page_source(view_key:, title:, options: {})
      GeneratedPacketSource.build_page_source(
        event: @event,
        view_key: view_key,
        title: title,
        options: options
      ).tap(&:save!)
    end

    def create_group_document(title:)
      document = @event.documents.create!(
        title: title,
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
      )

      document.packet_placements.create!(
        source: create_page_source(view_key: "section_break", title: title, options: {}),
        position: 1
      )
      document
    end
  end
end
end
