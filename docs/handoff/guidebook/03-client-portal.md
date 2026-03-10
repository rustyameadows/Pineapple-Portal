# Client Portal

## Purpose
The client portal is the client-facing surface for schedule, approvals, packets, payments, questionnaires, and shared links.

## Access model
- Uses event slug route namespace: `/client/<event-slug>/...`
- Client login/session required.

## Core portal areas
- Event homepage
- Decision Calendar + Run of Show calendar views
- Approvals
- Financials + individual payment pages
- Packets
- Questionnaires

## Publishing behavior highlights
- Calendars only show if run-of-show and/or client-visible derived views are available.
- Hidden or unavailable areas redirect with a “not yet published” style message.

## Decision Calendar behavior
- Segment-based list presentation.
- Click row to edit title/status/vendor/notes (modal flow).
