if defined?(RailsAgentAnnotator)
  RailsAgentAnnotator.configure do |config|
    config.enabled_environments = %w[development]
    config.enabled = Rails.env.development?
    config.allow_in_staging = false
    config.mount_path = "/__agent_annotator"
    config.storage_key_prefix = "rails_agent_annotator"
    # config.app_id = "my_app_unique_key"
    config.markdown_template = :v1
  end
end
