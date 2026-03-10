# Segments (Builder Rules)

## Segment types
- `pdf_asset`
- `html_view`

## Builder behavior
- Segment list supports reorder.
- Each segment supports preview and render status.
- HTML sections expose section-specific options.

## Text Page + Event Overview behavior from tests
- Markdown formatting is rendered (headings/lists/emphasis).
- Unsafe scripts and javascript links are sanitized.
- Custom `:::columns` directives render two-column layouts when valid.
- Malformed column directives are left as literal markdown text.
- Event Overview has starter fallback content when body markdown is blank.
