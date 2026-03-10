# Venues / Locations (Global + Event)

## Global Locations (Global Venues)
Purpose: reusable shared location records.

Manage:
- name
- contacts

Delete rule:
- cannot remove while linked to event venues.

## Event Locations
Purpose: event-specific location list used by operations and visibility rules.

Manage:
- name
- client visible toggle
- contacts
- order (move up/down)

## Linking behavior
- Event location can link to global location (`global_venue_id`).
- Duplicate global venue links in same event are blocked.
