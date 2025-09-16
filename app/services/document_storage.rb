class DocumentStorage
  ROOT = "documents".freeze

  def self.build_key(event:, logical_id:, version:, filename:)
    sanitized = sanitize_filename(filename)
    [ROOT, event.id, logical_id, "v#{version}", sanitized].join("/")
  end

  def self.sanitize_filename(filename)
    base = File.basename(filename.to_s)
    parameterized = base.gsub(/[^\w\.\-]+/, "-")
    parameterized.presence || "file"
  end
end
