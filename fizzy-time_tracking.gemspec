require_relative "lib/fizzy/time_tracking/version"

Gem::Specification.new do |spec|
  spec.name        = "fizzy-time_tracking"
  spec.version     = Fizzy::TimeTracking::VERSION
  spec.authors     = [ "37signals" ]
  spec.email       = [ "dev@37signals.com" ]
  spec.homepage    = "https://github.com/basecamp/fizzy"
  spec.summary     = "Time tracking engine for Fizzy"
  spec.description = "Rails engine that adds time tracking to Fizzy cards"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,db,lib}/**/*"]
  end

  spec.add_dependency "rails", ">= 8.1.0.beta1"
end
