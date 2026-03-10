# ROS Import Between Events

## What this feature is
This flow lets planners copy Run of Show items from one event into another event’s Run of Show.

## Where to do it
- Open the destination event.
- Go to **Timelines → Run of Show Calendar**.
- Click **Import Items**.

## What can be imported
- Entire source timeline, or selected items only.
- Source can be either:
  - the source event’s full Run of Show, or
  - one of that event’s saved derived timeline views.

## What gets copied
- Title, notes, duration, schedule timing, time caption, and tags.

## What is intentionally reset on import
- Status is reset to **Planned**.
- Lock state is removed.
- Vendor, location, and team assignments are cleared.

## Relative-time behavior
- If both an item and its anchor are imported, relative timing is preserved.
- If anchor is missing, the item falls back to an absolute time when possible.

## Where this shows up after import
Imported items appear directly in the destination event’s Run of Show table.

## Operator notes
- If no source event is selected, import cannot proceed.
- If no items are checked while using “Selected items,” import cannot proceed.
- The completion message calls out imported count, fallback conversions, and any tags auto-created during import.
