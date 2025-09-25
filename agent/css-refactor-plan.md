# CSS Refactor Plan

## Goals
- Move 100% of styles out of `legacy/legacy.css` into structured partials under `base/`, `layout/`, `components/`, `pages/`, and `utilities/`.
- Ensure every major surface (events, documents, payments, approvals, calendars, client portal) has a dedicated CSS entry point.
- Lean on a centralized token layer so future visual tweaks happen via variables, not scattered literals.
- Preserve current behavior while simplifying overrides and removing duplication.

## Target Structure
```
app/assets/stylesheets/
  base/
    tokens.css
    reset.css
    elements.css
  layout/
    app-shell.css        (global layout scaffolding)
    sidebar.css
    client-shell.css
    planner-shell.css
  components/
    buttons.css
    forms.css
    tables.css
    cards.css
    flash.css
    pills.css
    modal.css
    timeline.css
    event-links.css
    calendar-grid.css
    documents-table.css
    payments-list.css
    approvals-list.css
    tags.css
  pages/
    events-show.css
    events-index.css
    documents.css
    payments.css
    approvals.css
    client-designs.css
    client-financials.css
    client-questionnaires.css
  utilities/
    helpers.css
    responsive.css

  legacy/legacy.css (temporary; should shrink to zero)
```

## Migration Phases
1. **Token & Base confirmation**
   - Finalize typography, spacing, color tokens.
   - Ensure resets/elements provide sane defaults (already in place).

2. **Core layout & shared components**
   - Move global layout rules (planner/client shells, sidebar, event layout) into `layout/`.
   - Extract shared atoms: buttons, forms, tables, pills, flash, cards, modal, tags.
   - Replace raw colors/spacings with tokens.

3. **Feature components**
   - Calendar-specific: run-of-show pages, calendar grid, calendar tables, tag chips.
   - Documents: document tables, attachments, forms.
   - Payments & approvals: tables/cards + status treatments.

4. **Page-level wrappers**
   - For each controller/view set (events show/index, documents index/show, payments index/show, approvals index/show, client pages), create a `pages/` file that composes components + any necessary page overrides.

5. **Utilities**
   - Collect helper classes (visually-hidden, spacing tweaks, responsive helpers) under `utilities/` for consistency.

6. **Legacy teardown**
   - After each extraction, delete the corresponding block from `legacy/legacy.css`.
   - When legacy shrinks to zero, remove the file and its import.

## Execution Checklist
- [ ] Create empty partials for all target files and update manifest imports.
- [ ] Migrate layout rules (`event-layout`, `event-sidebar`, etc.) to `layout/app-shell.css` & friends.
- [ ] Extract shared button/form/table styles to token-based components.
- [ ] Move documents-specific styles to `components/documents-table.css` and `pages/documents.css`.
- [ ] Move calendar and grid styles to `components/calendar-grid.css` and `pages/events-calendar.css`.
- [ ] Move payments/approvals styling to `components/payments-list.css`, `components/approvals-list.css`, and `pages/events-payments.css`, `pages/events-approvals.css`.
- [ ] Migrate client portal pages (designs, financials, questionnaires) to `pages/client-*.css`.
- [ ] Centralize tag/pill styling in `components/tags.css` and update tag helper usage if needed.
- [ ] Extract utilities into `utilities/helpers.css` and replace scattered helper classes.
- [ ] Remove duplicate/residual rules from `legacy/legacy.css` until empty.

## Testing Plan
- After each migration chunk, smoke test key flows: planner events show, documents index, payments index/show, approvals index/show, calendar grid, client designs/financials/questionnaires.
- Use `bin/rails test` to ensure controller/view tests still pass.

## Notes
- Stay purely CSS + custom properties (no SASS) to align with Rails 8 + Propshaft.
- Maintain accessibility: ensure color combinations from tokens meet contrast requirements.
- Document new partial locations in README and share token usage conventions with the team.
