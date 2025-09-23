module Client
  class FinancialsController < EventScopedController
    def index
      @milestones = build_milestones
    end

    private

    def build_milestones
      [
        { label: "Deposit", due_on: nil, amount: nil, status: :completed },
        { label: "Planning Phase", due_on: nil, amount: nil, status: :upcoming },
        { label: "Design Phase", due_on: nil, amount: nil, status: :upcoming },
        { label: "Production", due_on: nil, amount: nil, status: :upcoming }
      ]
    end
  end
end
