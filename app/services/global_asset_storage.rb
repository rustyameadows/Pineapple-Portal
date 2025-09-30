class GlobalAssetStorage
  ROOT = "global-assets".freeze

  def self.build_key(filename:)
    sanitized = DocumentStorage.sanitize_filename(filename)
    [ROOT, SecureRandom.uuid, sanitized].join("/")
  end
end
