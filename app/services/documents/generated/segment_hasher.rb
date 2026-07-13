require "digest"

module Documents
  module Generated
    class SegmentHasher
      class << self
        def call(segment)
          new(segment).call
        end
      end

      def initialize(segment)
        @segment = segment
      end

      def call
        Digest::SHA256.hexdigest(JSON.dump(payload))
      end

      private

      attr_reader :segment

      def payload
        unless segment.is_a?(GeneratedPacketSource)
          return {
            document_logical_id: segment.document_logical_id,
            kind: segment.kind,
            title: segment.title,
            source_ref: canonical_source_ref,
            spec: canonical_spec
          }
        end

        {
          event_id: segment.event_id,
          kind: segment.kind,
          source_category: segment.source_category,
          canonical_key: segment.canonical_key,
          title: segment.title,
          source_ref: canonical_source_ref,
          spec: canonical_spec,
          dynamic: deep_sort(dynamic_payload)
        }
      end

      def canonical_source_ref
        deep_sort(segment.source_ref)
      end

      def canonical_spec
        deep_sort(segment.spec)
      end

      def dynamic_payload
        case segment.kind
        when GeneratedPacketSource::KINDS[:pdf_asset]
          pdf_document_payload
        when GeneratedPacketSource::KINDS[:html_view]
          html_view_payload
        when GeneratedPacketSource::KINDS[:group]
          group_payload
        else
          {}
        end
      end

      def pdf_document_payload
        document = UploadedDocumentResolver.new(segment).call
        return {} unless document

        {
          document_id: document.id,
          logical_id: document.logical_id,
          version: document.version,
          checksum: document.checksum,
          checksum_sha256: document.checksum_sha256,
          storage_uri: document.storage_uri,
          updated_at: document.updated_at&.utc&.iso8601
        }
      end

      def html_view_payload
        payload = case segment.html_view_key
        when "cover_sheet"
                    cover_payload
        when "planning_team"
                    planning_team_payload
        when DocumentSegment::EVENT_OVERVIEW_VIEW_KEY
                    event_overview_payload
        when DocumentSegment::VENDOR_CONTACTS_VIEW_KEY
                    vendor_contacts_payload
        when DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY
                    wedding_party_reference_payload
        when DocumentSegment::RUN_OF_SHOW_VIEW_KEY
                    timeline_payload(run_of_show: true)
        when DocumentSegment::TIMELINE_VIEW_KEY
                    timeline_payload(run_of_show: false)
        else
                    {}
        end

        with_shared_template_version(payload)
      end

      def group_payload
        document = segment.group_document
        return {} unless document

        {
          logical_id: document.logical_id,
          title: document.title,
          updated_at: document.updated_at&.utc&.iso8601,
          child_placements: document.packet_placements.ordered.map do |placement|
            {
              placement_id: placement.id,
              position: placement.position,
              source_id: placement.generated_packet_source_id,
              updated_at: placement.updated_at&.utc&.iso8601
            }
          end
        }
      end

      def cover_payload
        photo = segment.event.event_photo_document

        {
          event_name: segment.event.name,
          starts_on: segment.event.starts_on,
          ends_on: segment.event.ends_on,
          location: segment.event.location,
          event_photo: photo && {
            logical_id: photo.logical_id,
            checksum_sha256: photo.checksum_sha256,
            updated_at: photo.updated_at&.utc&.iso8601
          }
        }
      end

      def planning_team_payload
        segment.event.planner_team_members.includes(:user).ordered_for_display.map do |member|
          user = member.user
          {
            member_id: member.id,
            position: member.position,
            lead_planner: member.lead_planner?,
            user_id: user.id,
            name: user.name,
            title: user.title,
            avatar_global_asset_id: user.avatar_global_asset_id,
            user_updated_at: user.updated_at&.utc&.iso8601
          }
        end
      end

      def event_overview_payload
        {
          template_version: DocumentSegment::EVENT_OVERVIEW_TEMPLATE_VERSION,
          event: {
            name: segment.event.name,
            starts_on: segment.event.starts_on,
            ends_on: segment.event.ends_on,
            location: segment.event.location,
            guest_count: segment.event.guest_count,
            attire: segment.event.attire,
            style: segment.event.style,
            color_palette: segment.event.color_palette,
            social_media_policy: segment.event.social_media_policy,
            parking_details: segment.event.parking_details
          },
          milestone_items: event_overview_milestone_items_payload,
          vip_key_people: segment.event.event_guests.key_people.ordered.filter_map do |guest|
            next unless guest.vip?

            {
              guest_id: guest.id,
              first_name: guest.first_name,
              last_name: guest.last_name,
              relationship: guest.relationship,
              group_name: guest.group_name,
              position: guest.position,
              updated_at: guest.updated_at&.utc&.iso8601
            }
          end,
          planning_company: planning_company_profile_payload,
          planners: segment.event.planner_team_members.includes(:user).ordered_for_display.filter_map do |member|
            user = member.user
            next unless user

            {
              member_id: member.id,
              position: member.position,
              lead_planner: member.lead_planner?,
              user_id: user.id,
              name: user.name,
              title: user.title,
              email: user.display_email,
              phone_number: user.phone_number,
              user_updated_at: user.updated_at&.utc&.iso8601
            }
          end,
          venue_addresses: segment.event.event_venues.ordered.filter_map do |venue|
            address = venue.address.to_s.strip.presence
            next unless address

            {
              venue_id: venue.id,
              position: venue.position,
              name: venue.name.to_s.strip,
              address: address
            }
          end,
          vendors: Vendors::PlanningCompany
                   .excluding(segment.event.event_vendors)
                   .includes(:global_vendor)
                   .ordered
                   .filter_map do |vendor|
            {
              vendor_id: vendor.id,
              position: vendor.position,
              global_vendor_id: vendor.global_vendor_id,
              name: resolved_vendor_name(vendor),
              vendor_type: resolved_vendor_type(vendor),
              social_handle: normalized_social_handle(resolved_vendor_social_handle(vendor))
            }
          end
        }
      end

      def vendor_contacts_payload
        {
          template_version: DocumentSegment::VENDOR_CONTACTS_TEMPLATE_VERSION,
          pineapple_team_meals: segment.event.pineapple_team_meals.to_s.strip.presence,
          planning_company: planning_company_profile_payload,
          planners: segment.event.planner_team_members.includes(:user).ordered_for_display.filter_map do |member|
            user = member.user
            next unless user

            {
              member_id: member.id,
              position: member.position,
              lead_planner: member.lead_planner?,
              user_id: user.id,
              name: user.name,
              title: user.title,
              email: user.display_email,
              phone_number: user.phone_number,
              user_updated_at: user.updated_at&.utc&.iso8601
            }
          end,
          vendors: Vendors::PlanningCompany
                   .excluding(segment.event.event_vendors)
                   .includes(:global_vendor, event_vendor_contacts: :global_vendor_contact)
                   .ordered
                   .map do |vendor|
            {
              vendor_id: vendor.id,
              position: vendor.position,
              global_vendor_id: vendor.global_vendor_id,
              vendor_type: resolved_vendor_type(vendor),
              name: resolved_vendor_name(vendor),
              team_meals: vendor.team_meals.to_s.strip.presence,
              contacts: vendor.event_vendor_contacts.sort_by { |selection| [ selection.position, selection.id ] }.map do |selection|
                contact = selection.global_vendor_contact
                {
                  selection_id: selection.id,
                  selection_position: selection.position,
                  contact_id: contact.id,
                  name: contact.name.to_s.strip.presence,
                  title: contact.title.to_s.strip.presence,
                  email: contact.email.to_s.strip.presence,
                  phone: contact.phone.to_s.strip.presence,
                  notes: contact.notes.to_s.strip.presence
                }
              end
            }
          end
        }
      end

      def wedding_party_reference_payload
        {
          template_version: DocumentSegment::WEDDING_PARTY_REFERENCE_TEMPLATE_VERSION,
          event: {
            key_people_label: segment.event.key_people_label,
            getting_ready_details: segment.event.getting_ready_details
          },
          milestone_groups: wedding_party_reference_milestone_groups_payload,
          key_person_groups: segment.event.event_key_person_groups.includes(:event_calendar_tag).ordered.map do |group|
            {
              group_id: group.id,
              name: group.name,
              position: group.position,
              event_calendar_tag_id: group.event_calendar_tag_id,
              event_calendar_tag_name: group.event_calendar_tag&.name,
              updated_at: group.updated_at&.utc&.iso8601
            }
          end,
          key_people: segment.event.event_guests.key_people.ordered.map do |guest|
            {
              guest_id: guest.id,
              kind: guest.kind,
              first_name: guest.first_name,
              last_name: guest.last_name,
              relationship: guest.relationship,
              vip: guest.vip,
              event_key_person_group_id: guest.event_key_person_group_id,
              group_name: guest.group_name,
              position: guest.position,
              updated_at: guest.updated_at&.utc&.iso8601
            }
          end,
          wedding_party_timeline: wedding_party_reference_timeline_payload
        }
      end

      def wedding_party_reference_milestone_groups_payload
        calendar = segment.event.run_of_show_calendar
        timezone = calendar&.timezone.presence || Time.zone.name
        return [] unless calendar

        milestone_items = calendar.calendar_items
                                 .includes(:event_calendar_tags, :relative_anchor)
                                 .to_a
                                 .select(&:milestone?)
                                 .sort_by do |item|
          start_time = item.effective_starts_at&.in_time_zone(timezone)
          [ start_time&.to_f || Float::INFINITY, item.title.to_s.downcase ]
        end

        milestone_items
          .group_by do |item|
            start_time = item.effective_starts_at&.in_time_zone(timezone)
            start_time ? start_time.strftime("%A, %B %-d") : "Date TBD"
          end
          .map do |date_label, items|
            {
              date_label: date_label,
              items: items.map do |item|
                {
                  item_id: item.id,
                  title: item.title,
                  location_name: item.location_name,
                  notes: item.notes,
                  transportation_note: item.transportation_note,
                  time_caption: item.time_caption,
                  starts_at: item.starts_at&.utc&.iso8601,
                  effective_starts_at: item.effective_starts_at&.utc&.iso8601,
                  effective_ends_at: item.effective_ends_at&.utc&.iso8601,
                  duration_minutes: item.duration_minutes,
                  relative_anchor_id: item.relative_anchor_id,
                  relative_offset_minutes: item.relative_offset_minutes,
                  relative_before: item.relative_before,
                  relative_to_anchor_end: item.relative_to_anchor_end,
                  locked: item.locked,
                  updated_at: item.updated_at&.utc&.iso8601
                }
              end
            }
          end
      end

      def wedding_party_reference_timeline_payload
        timeline_data = Documents::Generated::WeddingPartyReferenceTimeline.new(
          event: segment.event,
          options: segment.html_options
        ).call

        {
          timezone: timeline_data[:timezone],
          show_day_headers: timeline_data[:show_day_headers],
          empty_message: timeline_data[:empty_message],
          columns: Array(timeline_data[:columns]).map do |column|
            column.slice(:tag_id, :tag_name, :group_id, :header)
          end,
          day_groups: Array(timeline_data[:day_groups]).map do |day_group|
            {
              date_label: day_group[:date_label],
              columns: Array(day_group[:columns]).map do |column|
                {
                  tag_id: column[:tag_id],
                  header: column[:header],
                  items: Array(column[:items]).map do |item|
                    {
                      item_id: item.id,
                      title: item.title,
                      notes: item.notes,
                      time_caption: item.time_caption,
                      location_name: item.location_name,
                      starts_at: item.starts_at&.utc&.iso8601,
                      effective_starts_at: item.effective_starts_at&.utc&.iso8601,
                      effective_ends_at: item.effective_ends_at&.utc&.iso8601,
                      duration_minutes: item.duration_minutes,
                      relative_anchor_id: item.relative_anchor_id,
                      relative_offset_minutes: item.relative_offset_minutes,
                      relative_before: item.relative_before,
                      relative_to_anchor_end: item.relative_to_anchor_end,
                      locked: item.locked,
                      tag_ids: item.event_calendar_tags.map(&:id).sort,
                      updated_at: item.updated_at&.utc&.iso8601
                    }
                  end
                }
              end
            }
          end
        }
      end

      def event_overview_milestone_items_payload
        calendar = segment.event.run_of_show_calendar
        timezone = calendar&.timezone.presence || Time.zone.name
        return { timezone: timezone, items: [] } unless calendar

        items = calendar.calendar_items
                        .includes(:event_calendar_tags, :relative_anchor)
                        .to_a
                        .select(&:milestone?)
                        .sort_by do |item|
          start_time = item.effective_starts_at&.in_time_zone(timezone)
          [ start_time&.to_f || Float::INFINITY, item.title.to_s.downcase ]
        end

        {
          timezone: timezone,
          items: items.map do |item|
            {
              item_id: item.id,
              position: item.position,
              title: item.title,
              location_name: item.location_name,
              guest_count: item.guest_count,
              time_caption: item.time_caption,
              starts_at: item.starts_at&.utc&.iso8601,
              effective_starts_at: item.effective_starts_at&.utc&.iso8601,
              effective_ends_at: item.effective_ends_at&.utc&.iso8601,
              duration_minutes: item.duration_minutes,
              relative_anchor_id: item.relative_anchor_id,
              relative_offset_minutes: item.relative_offset_minutes,
              relative_before: item.relative_before,
              relative_to_anchor_end: item.relative_to_anchor_end,
              locked: item.locked,
              updated_at: item.updated_at&.utc&.iso8601
            }
          end
        }
      end

      def timeline_payload(run_of_show:)
        calendar = segment.event.run_of_show_calendar
        return { error: "run_of_show_missing" } unless calendar

        view = nil
        items = if run_of_show
                  calendar.calendar_items.includes(:team_members).ordered.reject { |item| item.tagged_with?("decisions") }
        else
                  view_ref = segment.html_options["view_ref"].presence
                  view = calendar.event_calendar_views.find_by(id: view_ref)
                  return { error: "view_missing", view_ref: view_ref } unless view

                  filter = Calendars::ViewFilter.new(calendar: calendar, view: view)
                  filtered = filter.items
                  filtered = filtered.reject { |item| item.tagged_with?("decisions") } unless view.slug == "decision-calendar"
                  filtered
        end

        {
          run_of_show: run_of_show,
          segment_granularity: view&.segment_granularity || EventCalendarView::SEGMENT_GRANULARITIES[:day],
          items: Array(items).map do |item|
            {
              id: item.id,
              title: item.title,
              notes: item.notes,
              starts_at: item.starts_at&.utc&.iso8601,
              effective_starts_at: item.effective_starts_at&.utc&.iso8601,
              duration_minutes: item.duration_minutes,
              location_name: item.location_name,
              vendor_name: item.vendor_name,
              additional_team_members: item.additional_team_members,
              time_caption: item.time_caption,
              status: item.status,
              tag_summary: Array(item.tag_summary),
              team_members: item.team_members.map { |member| member.name.to_s.split.first }
            }
          end
        }
      end

      def with_shared_template_version(payload)
        if payload.is_a?(Hash)
          payload.merge(shared_template_version: DocumentSegment.shared_pdf_template_version)
        else
          {
            shared_template_version: DocumentSegment.shared_pdf_template_version,
            payload: payload
          }
        end
      end

      def deep_sort(value)
        case value
        when Hash
          value.keys.sort.each_with_object({}) do |key, result|
            result[key] = deep_sort(value[key])
          end
        when Array
          value.map { |entry| deep_sort(entry) }
        else
          value
        end
      end

      def resolved_vendor_name(vendor)
        vendor.global_vendor.name.to_s.strip
      end

      def planning_company_profile_payload
        event_vendor = Vendors::PlanningCompany.event_vendor_for(segment.event)
        global_vendor = event_vendor&.global_vendor
        return unless global_vendor

        {
          event_vendor_id: event_vendor.id,
          global_vendor_id: global_vendor.id,
          name: global_vendor.name.to_s.strip,
          social_handle: normalized_social_handle(global_vendor.default_social_handle)
        }
      end

      def resolved_vendor_type(vendor)
        vendor.vendor_type.to_s.strip.presence || vendor.global_vendor&.default_vendor_type.to_s.strip.presence
      end

      def resolved_vendor_social_handle(vendor)
        vendor.global_vendor.default_social_handle.to_s.strip.presence
      end

      def normalized_social_handle(value)
        handle = value.to_s.strip
        return if handle.blank?

        handle.start_with?("@") ? handle : "@#{handle}"
      end
    end
  end
end
