# frozen_string_literal: true

puts "Seeding screenshot demo data..."

planner = User.find_or_create_by!(email: "ada@example.com") do |user|
  user.name = "Ada Lovelace"
  user.password = "password123"
  user.role = :planner
end

client = User.find_or_create_by!(email: "jamie.rivera@example.com") do |user|
  user.name = "Jamie Rivera"
  user.password = "password123"
  user.role = :client
end

assistant = User.find_or_create_by!(email: "alex.kim@example.com") do |user|
  user.name = "Alex Kim"
  user.password = "password123"
  user.role = :planner
end

wedding = Event.find_or_create_by!(name: "Harper & Rivera Wedding Weekend") do |event|
  event.starts_on = Date.current + 45
  event.ends_on = Date.current + 47
  event.location = "Sonoma Valley"
  event.portal_slug = "harper-rivera-wedding"
end

wedding.update!(
  starts_on: Date.current + 45,
  ends_on: Date.current + 47,
  location: "Sonoma Valley",
  portal_slug: "harper-rivera-wedding"
)

[
  [planner, :planner, true],
  [assistant, :planner, false],
  [client, :client, false]
].each do |user, role, lead|
  member = EventTeamMember.find_or_initialize_by(event: wedding, user: user)
  member.member_role = role
  member.client_visible = true
  member.lead_planner = (role.to_sym == :planner && lead)
  member.save!
end

vendors = [
  ["Golden Hour Photography", "Nora Patel", "nora@goldenhourphoto.com"],
  ["Sweet Bloom Floral", "Mia Chen", "mia@sweetbloomfloral.com"],
  ["First Dance Band", "Jordan Ellis", "hello@firstdanceband.com"]
]

venues = [
  ["River House Estate", "Event Desk", "events@riverhouse.com"],
  ["Sunset Garden Pavilion", "Venue Team", "team@sunsetgarden.com"]
]

vendors.each_with_index do |(name, contact_name, email), index|
  vendor = GlobalVendor.find_or_initialize_by(normalized_name: GlobalVendor.normalize_name(name))
  vendor.name = name
  vendor.contacts_attributes = [{ name: contact_name, email: email, phone: "(555) 100-10#{index}" }]
  vendor.save!

  link = EventVendor.find_or_initialize_by(event: wedding, global_vendor: vendor)
  link.position = index
  link.notes = "Primary wedding partner"
  link.save!
end

venues.each_with_index do |(name, contact_name, email), index|
  venue = GlobalVenue.find_or_initialize_by(normalized_name: GlobalVenue.normalize_name(name))
  venue.name = name
  venue.contacts_attributes = [{ name: contact_name, email: email, phone: "(555) 200-20#{index}" }]
  venue.save!

  link = EventVenue.find_or_initialize_by(event: wedding, global_venue: venue)
  link.position = index
  link.notes = "Wedding weekend location"
  link.save!
end

run_of_show = EventCalendar.find_or_create_by!(event: wedding, kind: :master) do |calendar|
  calendar.name = "Run of Show"
  calendar.slug = "run-of-show"
  calendar.timezone = "America/Los_Angeles"
end

run_of_show.update!(name: "Run of Show", slug: "run-of-show", timezone: "America/Los_Angeles")

decision_calendar = EventCalendar.find_or_create_by!(event: wedding, slug: "decision-calendar") do |calendar|
  calendar.name = "Decision Calendar"
  calendar.kind = :derived
  calendar.timezone = "America/Los_Angeles"
end

decision_calendar.update!(name: "Decision Calendar", kind: :derived, timezone: "America/Los_Angeles")

critical_tag = run_of_show.event_calendar_tags.find_or_create_by!(name: "Critical") { |t| t.color = "#A855F7" }
milestone_tag = run_of_show.event_calendar_tags.find_or_create_by!(name: "Milestone") { |t| t.color = "#E11D48" }

base_time = Time.zone.parse("#{wedding.starts_on} 14:00")

items = [
  ["Hair + Makeup Begins", base_time, "Bridal Suite", "Golden Hour Photography", [critical_tag]],
  ["First Look Photos", base_time + 120.minutes, "Olive Grove", "Golden Hour Photography", [milestone_tag]],
  ["Ceremony", base_time + 240.minutes, "River House Lawn", nil, [critical_tag, milestone_tag]],
  ["Reception Grand Entrance", base_time + 390.minutes, "Sunset Garden Pavilion", "First Dance Band", [critical_tag]]
]

items.each_with_index do |(title, starts_at, location_name, vendor_name, tags), index|
  item = run_of_show.calendar_items.find_or_initialize_by(title: title)
  item.assign_attributes(
    starts_at: starts_at,
    duration_minutes: 60,
    notes: "Captured for screenshot walkthrough",
    location_name: location_name,
    vendor_name: vendor_name,
    position: index,
    status: :planned
  )
  item.save!
  item.event_calendar_tags = tags
  item.save!
end

decision_item = decision_calendar.calendar_items.find_or_initialize_by(title: "Choose signature cocktail")
decision_item.assign_attributes(
  starts_at: Time.zone.parse("#{wedding.starts_on - 14} 10:00"),
  duration_minutes: 30,
  notes: "Client picks one drink style",
  location_name: "Planning Studio",
  status: :to_be_confirmed,
  position: 0
)
decision_item.save!

payments = [
  ["Venue Final Payment", 12000, wedding.starts_on - 10, true, :pending],
  ["Floral Deposit", 2500, wedding.starts_on - 30, true, :paid],
  ["Band Balance", 4000, wedding.starts_on - 7, false, :pending]
]

payments.each do |title, amount, due_on, visible, status|
  payment = wedding.payments.find_or_initialize_by(title: title)
  payment.assign_attributes(
    amount: amount,
    due_on: due_on,
    description: "Wedding payment milestone",
    client_visible: visible,
    status: status
  )
  payment.paid_at = Time.current if status.to_sym == :paid
  payment.save!
end

approvals = [
  ["Reception floor plan", "Please confirm table spacing and dance floor.", true, :pending],
  ["Menu tasting selection", "Confirm final entree choices.", true, :approved],
  ["Invitation wording", "Returned with one wording note.", true, :acknowledged]
]

approvals.each do |title, summary, visible, status|
  approval = wedding.approvals.find_or_initialize_by(title: title)
  approval.assign_attributes(
    summary: summary,
    instructions: "Review and confirm this item with the couple.",
    client_visible: visible,
    status: status,
    client_name: "Jamie Rivera"
  )
  approval.acknowledged_at = Time.current if %w[approved acknowledged].include?(status.to_s)
  approval.client_note = "Can we soften the wording in section two?" if status.to_s == "acknowledged"
  approval.save!
end

puts "Screenshot demo data ready for event ##{wedding.id} (#{wedding.name})."
