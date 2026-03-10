# Tags in ROS Table View

## What this feature is
The Run of Show table now includes a dedicated **Tags** column so planners can quickly see classification/context for each timeline item.

## Where it appears
- Event shell: **Timelines → Run of Show Calendar**.
- Also reused in import preview tables where `show_tags` is enabled.

## How tags are shown
- If an item has tags: rendered as styled pills.
- If an item has no tags: rendered as “None”.

## Why this matters
- Faster scanning by type/theme/workstream.
- Better alignment with derived views and client-published views that rely on tagging.
- Reduces guesswork during import and timeline QA.

## Operator notes
- Tag definitions are managed in timeline/calendar tag controls.
- The table is read-first: tag editing still happens in item edit or tag management flows.
