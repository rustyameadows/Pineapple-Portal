# Calendar Milestones Plan

## 1. Data & Tagging Strategy
- Reuse the existing tag system: milestone designation relies on the presence of tag labels `milestones` or `critical`. Add helper methods on `CalendarItem` (e.g., `milestone?`, `critical?`) that check associated tags case-insensitively.
- Ensure tag creation/edit UI still allows planners to create those tags manually; no schema changes required.

## 2. Planner Settings View
- On the event settings page (`events/settings#show`), add an “Event Milestones” section that lists calendar items tagged `milestones`.
- Table columns: Title (links to the calendar-item edit screen), Schedule snippet, Timing snippet, and Tags for quick context—mirroring the main run-of-show table styling.
- Provide buttons to “Create Milestone” (opens new calendar item form with milestone tag preselected) and “Assign Existing Item” (links to the run-of-show view with grouping enabled for easy access).

## 3. Styling Rules
- Add CSS classes keyed off tags/status:
  - `.calendar-row--critical`: title red, bold; notes italic already (see below).
  - `.calendar-row--milestone`: title bold, accent color consistent with app.
  - `.calendar-row--completed`: strike-through the entire row or title when status is `completed`.
- Modify schedule tables (run-of-show and derived view) so the base title is regular weight, notes italicized. Apply new classes conditionally in the view partials based on helper methods.

## 4. Implementation Steps
1. **Helpers**: add `milestone?`, `critical?`, `status_class` methods in `CalendarHelper` (or a presenter) and an `CalendarItem#tagged_with?(name)` convenience.
2. **Planner Views**: update schedule table row wrappers to include conditional classes; italicize notes, remove explicit bold from titles. Remove status column and rely on strike-through for completed items.
3. **CSS**: introduce styling classes for milestone/critical/completed rows, plus italic note styling and base title weight adjustments.
4. **Testing**: add model test for `CalendarItem#milestone?`, view test (if practical) for milestone list inclusion, and update fixtures to include milestone-tagged items.

## 6. Rollout Considerations
- Highlight to planners that tagging any item with `Milestones` adds it to the special list; no additional toggle required.
- Future enhancement: dedicated “Mark as milestone” checkbox on the item form to transparently add/remove the tag.
