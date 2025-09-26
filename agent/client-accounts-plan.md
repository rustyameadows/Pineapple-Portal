# Client Accounts Implementation Plan

## 1. Access Model & Roles
- Add a `client` role to the existing `User` roles enum/constants; ensure it participates in validations/scopes.
- Reuse the existing `event_team_members` relationship to associate a client user with a single event (client users become a new role on that join model).
- Provide helper scopes (`User.clients`, `Event#client_users`) and authorization predicate methods (`User#client?`).
- Update any role-based guards to account for the new role (e.g., `planner?` checks should not assume binary admin/planner).

## 2. Authentication Flow & Sessions
- Create a dedicated controller namespace `Client::SessionsController` handling login/logout for client users, separate from planner/admin sessions.
- Maintain a distinct session key (`session[:client_user_id]`) to avoid overlap with staff sessions.
- Update `Client::BaseController` (or replace with `Client::PortalController`) to authenticate client sessions and ensure the user is related to the requested event via membership.

## 3. Client User Provisioning
- Extend the existing event team management UI to allow creating/assigning client-role users (stored via `event_team_members` with `role: :client`).

## 4. Portal Routing & Access Control
- Split portal routing: client login/register routes (e.g., `/portal/login`) pointing to client sessions controller.
- Ensure all existing portal controllers inherit authentication that checks role + team membership (via `event_team_members`); fallback to 403/redirect if unauthorized.
- Update URL helpers and navigation so staff can impersonate/test portal in staging without logging out.

## 5. Client Login UI
- Add a `app/views/client/sessions/new.html.erb` with brand-aligned styling, leveraging existing auth styles (`pages/auth.css`) adapted for portal tone.
- Include forgot password link placeholder (hook to existing passwords controller if available, otherwise stub for later).

## 6. Mailer & Notifications (Deferred)
- TODO: Add onboarding email to client accounts once base flow is stable.
- TODO: Consider notifying planners when client accounts activate.

## 7. Permissions Audit
- Review all controllers and views to ensure client role cannot access planner/admin dashboards (guard with `before_action :require_staff` where missing).
- Confirm document download and upload endpoints respect client visibility and membership.

## 8. Testing Strategy
- Model tests for `ClientMembership` associations and client role validations.
- Controller/system tests for:
  - Client login success/failure.
  - Unauthorized access to other events.
  - Portal navigation under client session.
- Update existing tests that assume only planner/admin roles.

## 9. Documentation & Operations
- Update README / internal docs describing how to create client accounts, assign to events, and expected login URL.
- Outline migration steps: run migrations, seed initial client users, update environment configs.

## Open Questions
- (None right now — capture new considerations during implementation.)
