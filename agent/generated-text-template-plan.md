# Generated Text Template Plan

## Summary
Add a new generated-document segment type that lets planners author arbitrary rich text for packet pages using a Markdown-style textarea.

Recommendation: implement Markdown-based input first (not Trix/ActionText) to fit current architecture and minimize migration risk.

## Why Markdown First
1. The generated segment system already persists per-segment options in `source_ref["options"]` JSON.
2. Branded sections are already pluggable via `DocumentSegment::HTML_VIEWS`.
3. ActionText/Trix is not wired in this app (no ActionText tables, no Trix imports/config), so Trix would be a much larger cross-cutting change.
4. Markdown + sanitize gives a fast path with good safety and print consistency for Grover PDFs.

## User Outcome
Planners can:
1. Add a new branded section type named as a general text page.
2. Enter arbitrary text in a textarea with simple Markdown syntax.
3. See formatted output in segment preview and compiled packet PDF.

## Scope
In scope:
1. New HTML view key for generated segment text pages.
2. Segment editor textarea for page content.
3. Markdown render + HTML sanitization.
4. New generated section template for preview/compile.
5. Styling for text page output and textarea ergonomics.
6. Tests for rendering and sanitization.

Out of scope:
1. Trix editor integration.
2. ActionText/ActiveStorage migrations.
3. Inline image uploads inside text content.
4. Versioned content history beyond existing segment/update behavior.

## Existing Architecture Touchpoints
1. Segment definition registry:
   `app/models/document_segment.rb` (`HTML_VIEWS`, `html_view_options`, `assign_html_view`).
2. Segment create/update payload handling:
   `app/controllers/documents/generated/segments_controller.rb` (`assign_html_payload`, `sanitize_html_view_options`).
3. Segment builder UI:
   `app/views/documents/generated/_segment_list.html.erb`.
4. Section rendering for preview and PDF:
   `app/views/generated_documents/sections/*`,
   `app/services/documents/generated/segment_renderer.rb`.
5. Template gallery:
   `app/controllers/documents/templates_controller.rb`,
   `app/views/documents/templates/index.html.erb`.
6. Styles:
   `app/assets/stylesheets/pages/documents.css`,
   shared generated base styles in `app/views/generated_documents/sections/_base_styles.html.erb`.

## Proposed Data Shape
For the new `html_view` key (example: `text_page`), store content in:

`source_ref["options"]`:
- `body_markdown` (String)

No schema migration required.

## Implementation Plan

### 1. Register the New Section
1. Update `app/models/document_segment.rb`.
2. Add new `HTML_VIEWS` entry (key, label, template, description), e.g.:
   - key: `text_page`
   - label: `Text Page`
   - template: `generated_documents/sections/text_page`
   - description: `General purpose formatted text section.`
3. Optional: add a constant for the key to avoid string scattering.

### 2. Sanitize and Persist Options
1. Update `app/controllers/documents/generated/segments_controller.rb`.
2. Extend `sanitize_html_view_options` with a branch for `text_page`.
3. Add a dedicated sanitizer method for this view that:
   - accepts only `body_markdown`,
   - stringifies/coerces value,
   - normalizes line endings,
   - applies a max length guard (recommended),
   - drops unknown keys.

### 3. Markdown Rendering Helper
1. Add parser dependency in `Gemfile` (recommended: `commonmarker`).
2. Add helper module `app/helpers/generated_documents_helper.rb` with:
   - `render_generated_markdown(markdown_string)`:
     - parse markdown to HTML,
     - sanitize with allowlist tags/attrs,
     - return safe HTML string for templates.
3. Include/ensure helper availability in section rendering context.

Suggested sanitize allowlist baseline:
1. Tags: `p`, `br`, `ul`, `ol`, `li`, `strong`, `em`, `h2`, `h3`, `blockquote`, `a`.
2. Attributes: `href`, `title`, `rel`, `target` on `a`.
3. Protocol guard: allow only `http`, `https`, `mailto`.

### 4. New Section Template
1. Add `app/views/generated_documents/sections/text_page.html.erb`.
2. Use the existing base style partial guard (`render_base_styles`).
3. Render page header partial for consistency.
4. Render markdown body via helper output.
5. If content is blank, render a muted placeholder so preview/gallery remain intelligible.

### 5. Builder UI: Textarea Settings
1. Update `app/views/documents/generated/_segment_list.html.erb`.
2. In the existing `segment.html_view?` edit section, add conditional branch for `text_page`:
   - `fields_for :options`
   - textarea bound to `body_markdown`
   - helper hint with supported syntax.
3. Keep existing title and view key controls intact.

### 6. Styling
1. Update `app/assets/stylesheets/pages/documents.css`.
2. Add textarea sizing/spacing styles for generated builder forms.
3. Add template content styles scoped to `generated-template--text-page`:
   - paragraph spacing,
   - list indentation,
   - heading scale,
   - blockquote style,
   - link styling.

### 7. Tests
Add/extend tests to cover behavior end-to-end:
1. View rendering test:
   - new file `test/views/generated_documents/text_page_section_test.rb`.
   - verifies markdown formatting output and placeholder on blank input.
2. Sanitization safety test:
   - same view test or helper test.
   - verifies unsafe tags/attrs are removed (e.g. script/event handlers/javascript URLs).
3. Segment option sanitization/controller path:
   - add controller test for segment update/create to assert only `body_markdown` persists for `text_page`.
4. Optional model-level test (if key constant added):
   - ensure `DocumentSegment.html_view?("text_page")` and config lookup behavior.

## Acceptance Criteria
1. “Text Page” appears in branded section pickers.
2. User can add and edit text content through textarea.
3. Preview shows formatted/sanitized text.
4. Compiled PDF includes formatted text page.
5. Unsafe HTML/URL payloads are not rendered.
6. Existing segment types continue to behave unchanged.
7. Test suite passes.

## Risks and Mitigations
1. Risk: unsafe HTML injection.
   Mitigation: strict sanitization allowlist after markdown parse.
2. Risk: oversized content causing poor pagination.
   Mitigation: length guard + clear UX guidance; rely on compile preview loop.
3. Risk: style mismatch between preview and compiled PDF.
   Mitigation: keep styles scoped to shared section template used by both flows.
4. Risk: option-key drift in JSON.
   Mitigation: sanitize options by view key and discard unknown keys.

## Rollout Sequence
1. Implement model/controller/template/helper/UI/CSS changes.
2. Add tests.
3. Run targeted tests for new section + full suite.
4. Manual QA in builder:
   - add section,
   - edit markdown,
   - preview,
   - compile and inspect PDF.

## Future Enhancements (Post-MVP)
1. Optional preset blocks/snippets (callouts, two-column notes).
2. Optional markdown toolbar hints in UI.
3. Optional richer typography controls (without full WYSIWYG).
4. Re-evaluate Trix/ActionText only if true rich editor requirements grow.
