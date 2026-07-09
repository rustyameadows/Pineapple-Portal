require "test_helper"
require "rake"

class VendorsRakeTest < ActiveSupport::TestCase
  setup do
    @previous_rake_application = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/vendors.rake")
  end

  teardown do
    Rake.application = @previous_rake_application
  end

  test "vendors audit prints only the fixed metric report" do
    report = Vendors::Audit::Report.new(Vendors::Audit::METRIC_KEYS.index_with(1))

    Vendors::Audit.stub(:run, report) do
      output, error = capture_io { Rake::Task["vendors:audit"].invoke }

      assert_empty error
      assert_equal "Vendor data audit (read-only)\n#{report}\n", output
      Vendors::Audit::METRIC_KEYS.each do |key|
        assert_includes output, "#{key}=1"
      end
    end
  end
end
