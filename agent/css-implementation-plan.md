# CSS Implementation Playbook

This walkthrough assumes the current Propshaft-native setup: partial styles live under `app/assets/stylesheets/{base,layout,components,pages,utilities}` and each layout enumerates the files it needs via `stylesheet_link_tag`.

## 1. Audit & Scope
1. Gather the design artifacts (Figma boards, component specs, typography tokens).
2. List the surfaces affected (planner layout, client portal, auth, etc.).
3. Decide what can be shared vs. view-specific so you know where the CSS needs to land.

## 2. Token Foundation (`base/`)
1. Update `base/tokens.css` with any new color scales, type ramps, spacing or radii.
2. Keep semantic variables (`--color-ink`, `--color-surface`, etc.) pointing at the new raw values so components consume tokens, not raw hex values.
3. Adjust `base/reset.css` / `base/elements.css` only when a global element default must change (e.g., new heading scale). Avoid page-specific tweaks here.

## 3. Utilities Pass (`utilities/`)
1. Add helper classes for spacing/layout patterns that repeat across pages.
2. Keep utilities minimal—if you need more than a class or two, consider a dedicated component instead.

## 4. Layout Chrome (`layout/`)
1. Work on global scaffolding: sidebar, shells, headers. These files control structural grid, background colors, breakpoints.
2. Confirm the order in `application`/`client` layouts still makes sense after edits (structural styles should load early).

## 5. Components (`components/`)
1. Build or adjust reusable pieces (buttons, cards, tables, tags). Components should depend only on token variables, not page context.
2. If a component grows new states, document expected markup/applied classes so future pages can reuse it.

## 6. Page-Level Styling (`pages/`)
1. For each view, create or edit its file under `pages/`. These files can assume the layout and components are already on the page.
2. Keep selectors scoped to page-specific wrappers to avoid leaking styles.

## 7. Wire Into Layouts
1. After adding a new partial, register it in the relevant layout list (`application.html.erb`, `client.html.erb`). Order matters—base/layout first, then components, then pages.
2. Reload locally; Propshaft reads straight from disk so no extra build step is needed.

## 8. Verify In Browser
1. Hard refresh (Cmd+Shift+R) to clear old cached bundles.
2. Check the network tab—no 404s, no missing styles.
3. Walk through each affected view on desktop and target breakpoints.

## 9. Accessibility & Performance
1. Run quick axe or Lighthouse checks for color contrast and heading order.
2. Confirm typography scales adapt correctly at breakpoints.

## 10. Tests & Documentation
1. Update snapshot/system tests if markup shifts.
2. Drop a short note in `README.md` or `agent-notes.md` summarizing new components or conventions so the next pass follows the same patterns.

## Tips
- Prefer semantic tokens to raw values so theme swaps stay centralized.
- When a page needs a brand-new layout, start with a `pages/` file and only move rules into `components/` once you see reuse.
- Keep mobile tweaks close to the rule they affect to avoid hunting across files later.
