# Run of Show (ROS)

## Purpose
Master operational timeline for event execution.

## Core operations
- Add/edit timeline items.
- Mark status.
- Lock/unlock items.
- Set absolute or relative timing.
- Assign vendor/location/team.
- Apply tags.

## ROS import between events
- Import all or selected items from another event.
- Source can be full run-of-show or a derived view.
- Imported copy keeps title/notes/timing/tags, but resets status/locks/assignments.

## What tests verify
Calendar item import tests verify selectors, invalid-state errors, and successful selected-item import redirect to Run of Show.
