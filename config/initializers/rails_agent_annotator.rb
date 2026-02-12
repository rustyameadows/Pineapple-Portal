RailsAgentAnnotator.configure do |config|
  config.enabled_environments = %w[development]
  config.enabled = Rails.env.development?
  config.allow_in_staging = false

  # Optional authorization hook when enabling outside development.
  # config.authorize = ->(controller) { controller.respond_to?(:current_user) && controller.current_user&.admin? }

  config.mount_path = "/__agent_annotator"
  config.storage_key_prefix = "rails_agent_annotator"
  config.markdown_template = :v1
end
