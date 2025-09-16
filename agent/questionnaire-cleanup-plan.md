# Questionnaire Cleanup Plan

## 1. Review Current Questionnaire Experience
- Inspect questionnaire/question models, controllers, and views to identify where metadata, question ordering, and attachments are presented.
- Note how attachments currently use context dropdowns and where positions are stored/managed.
- Confirm existing routes and partials that will need layout changes; ensure questionnaires are nested under events (no shallow routes).

## 2. Redesign Questionnaire Show Layout
- Update `questionnaires#show` to render a clear header block (title + description).
- Display questions in a two-column grid (1fr/1fr) where the left column shows the prompt/help and the right column shows the editable answer form (text input area + file upload + save button).
- Surface answer attachments within each question’s block and remove questionnaire-level attachment clutter.
- Provide inline validation/feedback when saving answers or uploading attachments.

## 3. Simplify Attachment Usage
- Restrict attachments to answer-level use cases—remove the context dropdown in the UI and default to `answer` when attaching via questionnaires.
- Ensure the attachment form aligns with the new layout (file upload and existing document picker as needed).

## 4. Question Ordering & Metadata
- Confirm `position` lives on questions; replace manual fields with a drag-and-drop reorder interface (e.g., using Stimulus + Sortable) so planners can arrange questions visually.
- Persist new ordering server-side and reflect it immediately in the UI.
- Update any controllers/tests impacted by layout/attachment changes.

## 5. Polish & Verify
- Refresh questionnaire-related tests (controller/view/system) to cover the new layout and attachment behavior.
- Update README or docs if necessary to describe the questionnaire workflow.
