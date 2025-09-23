module Client
  class BaseController < ApplicationController
    layout "client"

    helper_method :nav_link_class

    private

    def nav_link_class(target_path, starts_with: nil)
      classes = ["client-shell__nav-link"]
      is_active = helpers.current_page?(target_path)
      is_active ||= request.path.start_with?(starts_with) if starts_with.present?
      classes << "client-shell__nav-link--active" if is_active
      classes.join(" ")
    end
  end
end
