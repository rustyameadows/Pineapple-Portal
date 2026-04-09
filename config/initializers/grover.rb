Grover.configure do |config|
  pdf_base_url = ENV.fetch("PDF_BASE_URL", "http://localhost:3000")

  config.options = {
    format: "A4",
    display_url: pdf_base_url
  }
end
