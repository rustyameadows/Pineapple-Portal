# Payments & Approvals Build Plan

## 1. Data Model & Persistence
- Add `payments` table with core fields: event reference, title, amount (decimal), due_on, description/notes, client_visible flag, status enum (`pending`, `paid`), and timestamps for planner or client updates (e.g., `paid_at`, `paid_by_client_at`, `client_notes`).
- Add `approvals` table with event reference, title, summary text, client_visible flag, status enum (`pending`, `acknowledged`), optional client response fields (name, note, signed_at), and timestamps.
- Update models to declare relationships (`Event` has_many payments/approvals; `Payment`/`Approval` belongs_to event) plus basic validations and scopes (`ordered`, `visible_to_client`, `pending_first`).
- Extend `Attachment` support to allow linking approvals to uploaded documents (entity polymorphism + optional helper association like `has_many :attachments, as: :entity`).

NOTE - make the attachment work for payment or approvals. both may need one or more associated documents.

## 2. Planner Payments Management
- Wire nested routes (`resources :payments`) under events with standard CRUD actions.
- Implement controller/service logic so planners can list, create, update, delete payments, toggle paid state, and control client visibility.
- Build corresponding views: list page showing upcoming/paid breakdown, new/edit form partial, and simple status toggles. Reuse existing design tokens (tables, button classes) to stay consistent with remaining event UI.
- Surface recent payments summary in the event dashboard sidebar cards so planners see state at a glance. (NOTE - do not add anything to the event show view. just make the new views and make the links on the main section link to them)

## 3. Planner Approvals Management
- Add nested routes/controller/views for event approvals mirroring the payments flow.
- Form should let planners add headline, descriptive blurb, optional instructions for clients, and choose visibility. Provide attachment uploader slots via existing attachment component, limited to a couple documents per approval. (Note - dont code a hard limit on these)
- Listing view grouped by status (pending vs acknowledged) with quick access to manage attachments or retire an approval. (Note - do not group or filter or anything here. Just a list of all payment for that event. link to view or edit. you can show staus but dont filter or sort stuff)
- Provide action to archive/delete approvals without removing historical attachments; ensure client-visible flag defaults off until explicitly set.

## 4. Client Portal Updates
- Replace stubbed `Client::FinancialsController#index` with real data: pull client-visible payments, format amount/due dates, compute status display, and expose a "Mark as Paid" action that flips status + timestamps.
- Add confirmation flow for the mark-paid action (simple POST/PATCH) with optional note input. Persist client note + autopopulate `paid_by_client_at` for planner context.
- Introduce client approvals page (new controller & template under `portal/events/:event_id/approvals`) that lists visible approvals, shows descriptive text, attachments for download, and optionally lets clients acknowledge/submit a short response. (Note - do not add approvals to the portal views. only do the payment ones on the portal side)
- Ensure the client dashboard card for Financials/Approvals reflects counts or next due item to help clients prioritize tasks. (note - don't touch the portal event show page. not in your scope. just add the new views for payments)

## 5. Navigation & Event Overview
- Update event sidebar navigation to link to the new planner-facing payments and approvals sections instead of placeholder `#` anchors.
- Refresh `events/show` overview: replace static payment/approval link groups with live data (e.g., next due payment, outstanding approvals) while keeping layout consistent.
- Add client portal navigation entries (if missing) for approvals so both planner and client sides share a coherent flow.

## 6. Attachments & Document Handling
- Allow attachments to reference approvals via controller whitelist changes and helper methods (e.g., `Attachment#event` fallback).
- Adjust attachment partials/forms to pass the new entity type and ensure any validations (position, context) remain valid.
- Consider adding lightweight document previews or filenames in both planner and client approvals views.

## 7. Validation, Tests & Seeds
- Create model specs covering validations, scopes, client visibility flows, and client mark-as-paid/acknowledged transitions.
- Add controller/request specs for core planner actions and client interactions (mark paid/acknowledge).
- Update fixtures or factories for events to include representative payments/approvals so both sides render during development.
- Verify UI manually (or via system specs if time permits) for both roles, focusing on creation/edit flows, portal visibility toggles, and attachment upload paths.

## 8. Follow-Up Considerations
- Introduce soft-delete/archive flags if planners need to retire items without losing history.
- Integrate notifications or dashboard badges once broader alerting framework exists.
- Revisit security/authorization once client accounts and role separation are implemented.
