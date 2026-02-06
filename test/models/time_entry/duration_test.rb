require "test_helper"

class TimeEntry::DurationTest < ActiveSupport::TestCase
  test "zero minutes" do
    assert_equal "0m", TimeEntry::Duration.new(0).to_s
  end

  test "minutes only" do
    assert_equal "45m", TimeEntry::Duration.new(45).to_s
  end

  test "exact hours" do
    assert_equal "2h 0m", TimeEntry::Duration.new(120).to_s
  end

  test "hours and minutes" do
    assert_equal "1h 30m", TimeEntry::Duration.new(90).to_s
  end

  test "days hours and minutes" do
    assert_equal "2d 1h 15m", TimeEntry::Duration.new(1035).to_s
  end

  test "exact days" do
    assert_equal "1d 0m", TimeEntry::Duration.new(480).to_s
  end

  test "one day equals eight hours" do
    duration = TimeEntry::Duration.new(480)

    assert_equal 1, duration.days
    assert_equal 0, duration.hours
    assert_equal 0, duration.remaining_minutes
  end

  test "accessors" do
    duration = TimeEntry::Duration.new(1035)

    assert_equal 2, duration.days
    assert_equal 1, duration.hours
    assert_equal 15, duration.remaining_minutes
    assert_equal 1035, duration.total_minutes
  end

  test "omits zero hours" do
    assert_equal "1d 30m", TimeEntry::Duration.new(510).to_s
  end
end
