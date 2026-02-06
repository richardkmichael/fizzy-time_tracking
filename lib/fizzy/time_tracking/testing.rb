# Add engine fixtures to the test fixture paths
module Fizzy::TimeTracking::EngineFixtures
  def included(base)
    super
    engine_fixtures = Fizzy::TimeTracking::Engine.root.join("test", "fixtures").to_s
    base.fixture_paths << engine_fixtures unless base.fixture_paths.include?(engine_fixtures)
  end
end

ActiveRecord::TestFixtures.singleton_class.prepend(Fizzy::TimeTracking::EngineFixtures)
