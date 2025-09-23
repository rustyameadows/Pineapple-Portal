module Client
  class GuestListsController < EventScopedController
    def show
      @guest_summary = []
    end
  end
end
