require "test_helper"

class TimeEntryTimelineTest < ActionDispatch::IntegrationTest
  test "TIMELINEABLE_ACTIONS includes time_entry_created" do
    assert_includes User::DayTimeline::TIMELINEABLE_ACTIONS, "time_entry_created"
  end

  test "PERMITTED_ACTIONS includes time_entry_created" do
    assert_includes Webhook::PERMITTED_ACTIONS, "time_entry_created"
  end

  test "time entry creation creates event" do
    sign_in_as :david

    assert_difference -> { Event.count }, +1 do
      post card_time_entries_path(cards(:logo)), params: { time_entry: { minutes: 30, date: Date.current } }, as: :turbo_stream
    end

    event = Event.last

    assert_equal "time_entry_created", event.action
  end

  test "notifier discovery" do
    Current.session = sessions(:david)

    time_entry = cards(:logo).time_entries.create!(total_minutes: 30, date: Date.current)
    event = time_entry.events.last

    notifier = Notifier.for(event)

    assert_instance_of Notifier::TimeEntryEventNotifier, notifier
  end
end
