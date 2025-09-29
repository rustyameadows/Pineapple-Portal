module Events
  class SettingsController < ApplicationController
    before_action :set_event
    helper CalendarHelper

    def show
      @event_link = @event.event_links.new
      @event_links = @event.event_links.ordered
      @event_vendor = @event.event_vendors.new(client_visible: true)
      @event_vendors = @event.event_vendors.ordered
      @event_venue = @event.event_venues.new(client_visible: true)
      @event_venues = @event.event_venues.ordered
      @planner_team_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:planner]
      )

      @client_team_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:client]
      )
      @client_team_member.client_user_attributes = {}

      @planner_team_members = @event.planner_team_members
                                    .includes(:user)
                                    .left_joins(:user)
                                    .ordered_for_display
                                    .order("users.name")

      @client_team_members = @event.client_team_members
                                   .includes(user: :password_reset_tokens)
                                   .left_joins(:user)
                                   .order("users.name")

      @client_link_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:client]
      )

      assigned_user_ids = (@planner_team_members + @client_team_members).map(&:user_id)

      @available_planners = User.planners.order(:name)
      @available_planners = @available_planners.where.not(id: assigned_user_ids) if assigned_user_ids.any?

      @available_clients = User.clients.order(:name)
      @available_clients = @available_clients.where.not(id: assigned_user_ids) if assigned_user_ids.any?

      @calendar = @event.run_of_show_calendar
      if @calendar.nil?
        @calendar = @event.event_calendars.create!(
          name: "Run of Show",
          timezone: EventCalendar::DEFAULT_TIMEZONE
        )
      end

      @milestone_items = @calendar.calendar_items
                                  .includes(:event_calendar_tags, :team_members)
                                  .select(&:milestone?)

      @unified_people = build_unified_people
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def build_unified_people
      vendor_people = @event_vendors.flat_map.with_index do |vendor, vendor_index|
        vendor.contacts.each_with_index.map do |contact, contact_index|
          build_person_card(
            uid: "vendor-contact-#{vendor.id}-#{contact_index}",
            event_id: vendor.event_id,
            source_type: :vendor,
            source_id: vendor.id,
            source_name: vendor.name,
            contact_index:,
            position: vendor.position,
            client_visible: vendor.client_visible,
            contact:,
            group_label: "Vendor"
          )
        end
      end

      venue_people = @event_venues.flat_map.with_index do |venue, venue_index|
        venue.contacts.each_with_index.map do |contact, contact_index|
          build_person_card(
            uid: "venue-contact-#{venue.id}-#{contact_index}",
            event_id: venue.event_id,
            source_type: :venue,
            source_id: venue.id,
            source_name: venue.name,
            contact_index:,
            position: venue.position,
            client_visible: venue.client_visible,
            contact:,
            group_label: "Venue"
          )
        end
      end

      planner_people = @event.planner_team_members.includes(:user).map do |team_member|
        user = team_member.user
        build_person_card(
          uid: "planner-#{team_member.id}",
          event_id: team_member.event_id,
          source_type: :planner,
          source_id: team_member.id,
          source_name: "Planning Team",
          contact_index: 0,
          position: team_member.position,
          client_visible: team_member.client_visible?,
          contact: {
            "name" => user&.name,
            "title" => user&.title,
            "email" => user&.email,
            "phone" => user&.phone_number,
            "notes" => nil
          },
          group_label: "Planner"
        )
      end

      client_people = @event.client_team_members.includes(:user).map do |team_member|
        user = team_member.user
        build_person_card(
          uid: "client-#{team_member.id}",
          event_id: team_member.event_id,
          source_type: :client,
          source_id: team_member.id,
          source_name: "Client",
          contact_index: 0,
          position: team_member.position,
          client_visible: team_member.client_visible?,
          contact: {
            "name" => user&.name,
            "title" => user&.title,
            "email" => user&.email,
            "phone" => user&.phone_number,
            "notes" => nil
          },
          group_label: "Client"
        )
      end

      (vendor_people + venue_people + planner_people + client_people)
        .compact
        .sort_by { |person| [person[:group_sort], person[:position], person[:contact_index], person[:name].to_s] }
    end

    GROUP_SORT_ORDER = {
      vendor: 0,
      venue: 1,
      planner: 2,
      client: 3
    }.freeze

    def build_person_card(uid:, event_id:, source_type:, source_id:, source_name:, contact_index:, position:, client_visible:, contact:, group_label:)
      name = contact.to_h["name"].presence || source_name
      return if name.blank?

      {
        uid:,
        event_id:,
        source_type:,
        source_id:,
        source_name:,
        contact_index:,
        position:,
        client_visible:,
        name:,
        title: contact.to_h["title"].presence,
        email: contact.to_h["email"].presence,
        phone: contact.to_h["phone"].presence,
        notes: contact.to_h["notes"].presence,
        group_label:,
        group_sort: GROUP_SORT_ORDER.fetch(source_type, 99)
      }
    end
  end
end
