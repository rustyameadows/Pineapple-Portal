module Settings
  class RunOfShowDefaultsController < ApplicationController
    helper CalendarHelper
    before_action :require_admin!

    def show
      @default_tags = RunOfShowDefaults::TAGS
    end
  end
end
