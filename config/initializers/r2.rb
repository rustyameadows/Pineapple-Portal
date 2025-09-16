Rails.application.config.x.r2 = {
  bucket: ENV["R2_BUCKET"],
  account_id: ENV["R2_ACCOUNT_ID"],
  endpoint: ENV["R2_ENDPOINT"],
  region: ENV.fetch("R2_REGION", "auto")
}.freeze
