# Codex Work Checklist

- Always draft and share a clear implementation plan **before** writing or modifying any code; wait for explicit approval from the user.
- Never modify or delete an existing migration unless the user confirms it has not been run. If unsure, ask first.
- For every significant change, note whether a migration or data task is required so the user can run it themselves.
- Confirm timezone assumptions and form behavior with the user when adding date/time inputs.
- Default to non-destructive approaches: prefer controller/view/service changes over schema edits unless specifically requested.
- Keep UI tweaks aligned with existing design tokens; avoid introducing new styles without verifying they fit the design system.
- When adding tests, ensure fixtures are left consistent with production expectations (no hard-coded UTC assumptions).
- Before finishing, outline validation steps so the user can reproduce results (tests, commands, manual checks).
