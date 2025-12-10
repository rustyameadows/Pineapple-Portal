module Settings
  class RunOfShowDefaultsController < ApplicationController
    helper CalendarHelper

    def show
      @default_tags = RunOfShowDefaults::TAGS
    end
  end
end
