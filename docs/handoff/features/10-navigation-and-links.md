# Navigation and Links Cleanup

## What this feature is
Navigation was standardized so users can reliably move between account-level admin areas and event-level workspaces, with clearer active states and safer path matching.

## Account-level (index shell) navigation
Main left sidebar links:
- Events
- Vendors (global)
- Locations (global)
- Team
- Settings

## Event-level navigation
Per-event sidebar sections:
- Event Info (General Info, Client Portal, Clients, Vendors, Locations, Planners)
- Timelines (Run of Show, derived views, Calendar Settings)
- Packets (generated docs and each doc link)
- Uploads
- People
- Questionnaires
- Payments
- Approvals

## Link behavior improvements
- Active state logic uses section match paths and path-boundary checks.
- Stub/placeholder links are rendered non-navigable where content is not available yet.
- Sidebar matching intentionally avoids false positives for view routes and generated-doc route overlaps.

## Why this matters for handoff
A non-technical user can now follow consistent left-nav patterns:
- account-level setup first,
- then event-specific execution,
- then client-facing publication.
