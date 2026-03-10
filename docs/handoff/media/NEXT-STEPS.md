# Next Steps for Adding Imagery

This handoff packet is ready for image capture on any machine (or agent) that can run the app locally.

## 1) Generate the wedding demo data
```bash
bundle exec rails runner script/bootstrap_screenshot_data.rb
```

## 2) Start the app
```bash
bin/rails server
```

## 3) Capture the standard screenshot pack
```bash
node script/capture_handoff_media.mjs
```

## 4) Confirm files exist
You should now have:
- `docs/handoff/media/01-planner-dashboard.png`
- `docs/handoff/media/02-global-vendors.png`
- `docs/handoff/media/03-global-locations.png`
- `docs/handoff/media/04-ros-table.png`
- `docs/handoff/media/05-ros-item-edit.png`
- `docs/handoff/media/06-decision-calendar.png`
- `docs/handoff/media/07-approvals.png`
- `docs/handoff/media/08-payments.png`
- `docs/handoff/media/09-client-dashboard.png`

## 5) Commit and open PR
```bash
git add docs/handoff/media/*.png
git commit -m "Add handoff app screenshots"
```
