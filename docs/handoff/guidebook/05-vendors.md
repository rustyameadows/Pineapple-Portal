# Vendors (Global + Event)

## Global Vendors (account-level)
Purpose: reusable shared vendor records across all events.

Manage:
- name
- default vendor type
- default social handle
- contacts list

Delete rule:
- cannot remove while linked to event vendors.

## Event Vendors (event-level)
Purpose: event-specific vendor list, ordering, and visibility.

Manage:
- name
- vendor type
- social handle
- client visible toggle
- contacts
- order (move up/down)

## Linking behavior
- Event vendor can link to global vendor (`global_vendor_id`).
- New names can auto-create/find global vendor for consistency.
- Duplicate global vendor links in same event are blocked.
