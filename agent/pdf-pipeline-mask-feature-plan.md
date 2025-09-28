# PDF Masking & Numbering Feature Plan

## Objective
Ensure generated document packets display only the final sequential page numbers by masking pre-numbered segment PDFs before compilation and then applying consistent numbering across the merged document.

## Stage 1 – Segment-Level Masking
- Identify segment templates that render internal page numbers.
- For each flagged segment, overlay an opaque rectangle sized and positioned to cover the existing number without disturbing surrounding content.
- Parameterize rectangle attributes (coordinates, dimensions, fill color, opacity) to support portrait/landscape variants and differing margin schemes.
- Validate the neutral appearance of masked pages (matching background color, no visible artifacts) across sample segments.

## Stage 2 – Packet-Level Numbering
- Merge masked segments with current CombinePDF pipeline.
- Apply `CombinePDF#number_pages` once on the compiled PDF, configuring placement, font, and offset per product requirements.
- Confirm numbering sequence continuity across segment boundaries and with optional appendices.

## Tooling & Implementation Notes
- Use `CombinePDF.create_page` + `textbox` overlays for masks; rely on `box_color`/`opacity` for full coverage.
- Store per-segment mask metadata alongside render configuration, enabling opt-in masking without touching unaffected PDFs.
- Introduce automated checks (unit/integration) to ensure masked segments and final numbering render as expected.

## Open Questions
- What reliable signal (metadata flag, template tag, etc.) identifies segments needing masking?
- Do any segments require multiple mask regions (e.g., headers/footers) or non-rectangular coverage?
- Are there locale-specific or product-specific numbering formats that affect placement or styling?

## Next Steps
- Align with product/design on final page-number styling and mask appearance.
- Prototype masking on a representative segment and capture before/after renders for review.
- Extend the documents compiler to inject masks based on segment metadata, then add the final numbering pass.
- Add regression tests around masked segments and packet numbering flow.
