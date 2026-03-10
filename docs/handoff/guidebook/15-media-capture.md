# Media Capture (App Screenshots + Optional Recordings)

## Goal
This page is the handoff playbook for capturing **real app screens** using the same wedding demo data every time.

## What this PR already includes
- A repeatable data bootstrap script: `script/bootstrap_screenshot_data.rb`
- A repeatable screenshot script: `script/capture_handoff_media.mjs`
- A stable screenshot folder: `docs/handoff/media/`

## Next steps (run on a machine with local app access)
1. Install gems + app dependencies.
2. Prepare database and seed base app data.
3. Run the screenshot bootstrap script.
4. Start the app locally.
5. Run the screenshot capture script.
6. Commit the generated PNG files in `docs/handoff/media/`.

### Copy/paste runbook
```bash
bundle install
npm install
bin/rails db:prepare
bundle exec rails db:seed
bundle exec rails runner script/bootstrap_screenshot_data.rb
bin/rails server
# in a second terminal:
node script/capture_handoff_media.mjs
```

## Screenshot bootstrap data
Sign in as:
- Email: `ada@example.com`
- Password: `password123`

The bootstrap script prepares a wedding planning scenario with:
- A populated wedding event
- Planner + client team members
- Global vendors and global locations
- Run of Show items and tags
- Decision calendar item
- Approvals and payments

## Required screenshot pack
Store all images in `docs/handoff/media/`.

| Capture | Status | File |
|---|---|---|
| Planner dashboard | Pending capture | `docs/handoff/media/01-planner-dashboard.png` |
| Global vendors | Pending capture | `docs/handoff/media/02-global-vendors.png` |
| Global locations | Pending capture | `docs/handoff/media/03-global-locations.png` |
| ROS table view | Pending capture | `docs/handoff/media/04-ros-table.png` |
| ROS item edit screen | Pending capture | `docs/handoff/media/05-ros-item-edit.png` |
| Decision Calendar | Pending capture | `docs/handoff/media/06-decision-calendar.png` |
| Approvals | Pending capture | `docs/handoff/media/07-approvals.png` |
| Payments | Pending capture | `docs/handoff/media/08-payments.png` |
| Client dashboard | Pending capture | `docs/handoff/media/09-client-dashboard.png` |

## Optional recording pack
If needed for handoff playback, add short walkthrough clips for:
- Client dashboard walkthrough
- ROS edit flow
- Decision Calendar check-in flow
- Approvals response flow
- Payment status flow
