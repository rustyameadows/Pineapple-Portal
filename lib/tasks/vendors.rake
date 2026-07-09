namespace :vendors do
  desc "Print a read-only, PII-safe audit of vendor data and ROS vendor values"
  task audit: :environment do
    puts "Vendor data audit (read-only)"
    puts Vendors::Audit.run
  end
end
