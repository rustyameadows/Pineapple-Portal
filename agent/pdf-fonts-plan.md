# PDF Font Embedding Plan

Goal: ensure Grover-generated PDFs use Sackers, MrsEaves, and other brand fonts exactly as the browser does, without altering the app-wide CSS pipeline.

## 1. Environment Setup
- Introduce `PDF_BASE_URL` (or reuse an existing `ASSET_HOST`) in each environment that produces PDFs.
  - Development example: `PDF_BASE_URL=http://localhost:3000`
  - Production example: `PDF_BASE_URL=https://portal.yourdomain.com`
- This host must serve the compiled Rails assets (fonts, CSS, JS) that Grover will request.

## 2. Grover Configuration
- Update `config/initializers/grover.rb` so the renderer knows the canonical origin:
  ```ruby
  Grover.configure do |config|
    host = ENV.fetch("PDF_BASE_URL") { "http://localhost:3000" }
    config.options = {
      display_url: host,
      base_url: host,
      format: "A4"
    }
  end
  ```
- `display_url` (and `base_url`) give headless Chrome the right protocol + host to resolve `/assets/...` URLs emitted by Rails helpers.

## 3. PDF-Only Font Declarations
- Create a partial dedicated to Grover styling, e.g. `app/views/shared/_pdf_fonts.html.erb`.
- Inside that partial, embed inline `@font-face` rules referencing absolute asset URLs while bypassing other layouts:
  ```erb
  <% font_host = ENV.fetch("PDF_BASE_URL") { AssetUrl.default_host } %>
  <style>
    @font-face {
      font-family: "SackersGothic";
      src: url("<%= asset_url("SackersGothicStd-Medium.woff2", host: font_host) %>") format("woff2"),
           url("<%= asset_url("SackersGothicStd-Medium.woff", host: font_host) %>") format("woff"),
           url("<%= asset_url("SackersGothicStd-Medium.ttf", host: font_host) %>") format("truetype");
      font-style: normal;
      font-weight: 500;
    }
    <!-- repeat for MrsEaves, Didot, Baskerville, etc. -->
  </style>
  ```
- Add helper logic (`AssetUrl.default_host`) if needed to centralise host fallback.

## 4. Apply to PDF Layout
- Include the partial at the top of every PDF layout or template used by Grover, e.g. `app/views/layouts/pdf.html.erb`:
  ```erb
  <%= render "shared/pdf_fonts" %>
  ```
- Because the partial is only rendered for Grover views, the rest of the application’s CSS remains untouched.

## 5. Verification
1. Precompile assets to ensure digested font files exist.
2. From production, request one of the generated font URLs (e.g. `curl "$PDF_BASE_URL/assets/SackersGothicStd-Medium-<digest>.woff2"`) to confirm it’s reachable.
3. Render a PDF via Grover; inspect logs or network traces to ensure the browser fetches the fonts from the configured host.
4. Confirm typography inside the PDF now matches the in-browser rendering.

## 6. Optional Fallback
- If exposing `/assets/…` isn’t feasible, copy fonts into a public directory (e.g. `public/pdf-fonts/`) and adjust the partial to point there. This is only necessary if your deployment can’t serve digest paths.

Outcome: Grover’s headless Chrome downloads the exact same font binaries that style the live site, eliminating server-side fallbacks while leaving the regular asset pipeline untouched.
