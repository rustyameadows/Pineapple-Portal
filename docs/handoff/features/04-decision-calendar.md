# Decision Calendar Improvements

## What this feature is
A client-facing calendar mode focused on decision tracking (task, status, vendor, notes) with in-place editing through a modal.

## Where clients access it
- Client portal route: `/<event-slug>/decision-calendar`
- Served through the client calendars controller as a special view when the slug is `decision-calendar`.

## What is improved
- Decision items are grouped into readable segments.
- Rows are clickable and open a modal editor.
- Modal loads item JSON on demand and updates status/vendor/notes/title.
- Sticky headers improve scanability of task/status/vendor/notes columns.

## What fields are editable in the decision modal
- Title
- Status
- Vendor name
- Notes

## Where planners control visibility/source
- Decision Calendar is a client-visible calendar view derived from Run of Show/tag filtering.
- If no accessible/published client calendar exists, clients are redirected with a “not yet published” message.

## Operator notes
- This page is for decision workflow clarity, not full scheduling operations.
- It is intentionally optimized for quick updates and client feedback loops.
