# Event Settings + Field Reference

## Purpose
This is the “API-style but approachable” reference for event settings.

## Event Info → General Info fields
- **Event Title** (`name`): required display name.
- **Location** (`location`): primary venue/location line.
- **Secondary location line** (`location_secondary`): city/state or supporting location text.
- **Client portal slug** (`portal_slug`): vanity URL suffix for `/client/<slug>`.
- **Start Date** (`starts_on`)
- **End Date** (`ends_on`)
- **Event Photo** (`event_photo_document_id`): selected from uploaded images.

## Event settings sub-pages
- General Info
- Client Portal
- Clients
- Vendors
- Locations
- Planners

## Internal links on settings page
Internal planner shortcuts are managed separately from client portal links.
Fields:
- `label`
- `url`
- `link_type=internal`

## What tests verify
Settings controller tests confirm each sub-page route renders expected headings (General, Client Portal, Clients, Vendors, Locations, Planners).
