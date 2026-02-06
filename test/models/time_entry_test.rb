require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "valid time entry" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: 60, date: Date.current)

    assert time_entry.persisted?
  end

  test "requires total_minutes" do
    time_entry = cards(:logo).time_entries.build(date: Date.current)

    assert_not time_entry.valid?
    assert time_entry.errors[:total_minutes].any?
  end

  test "total_minutes must not be zero" do
    time_entry = cards(:logo).time_entries.build(total_minutes: 0, date: Date.current)

    assert_not time_entry.valid?
    assert time_entry.errors[:total_minutes].any?
  end

  test "total_minutes must be integer" do
    time_entry = cards(:logo).time_entries.build(total_minutes: 1.5, date: Date.current)

    assert_not time_entry.valid?
    assert time_entry.errors[:total_minutes].any?
  end

  test "requires date" do
    time_entry = cards(:logo).time_entries.build(total_minutes: 60)

    assert_not time_entry.valid?
    assert time_entry.errors[:date].any?
  end

  test "description is optional" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: 60, date: Date.current)

    assert_nil time_entry.description
  end

  test "defaults creator to Current.user" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: 60, date: Date.current)

    assert_equal Current.user, time_entry.creator
  end

  test "defaults account to card account" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: 60, date: Date.current)

    assert_equal cards(:logo).account, time_entry.account
  end

  test "creates event on creation" do
    assert_difference -> { Event.count }, +1 do
      cards(:logo).time_entries.create!(total_minutes: 60, date: Date.current)
    end

    assert_equal "time_entry_created", Event.last.action
  end

  test "combines hours and minutes into total_minutes" do
    time_entry = cards(:logo).time_entries.create!(hours: 1, minutes: 30, date: Date.current)

    assert_equal 90, time_entry.total_minutes
  end

  test "combines with only hours" do
    time_entry = cards(:logo).time_entries.create!(hours: 2, date: Date.current)

    assert_equal 120, time_entry.total_minutes
  end

  test "combines with only minutes" do
    time_entry = cards(:logo).time_entries.create!(minutes: 45, date: Date.current)

    assert_equal 45, time_entry.total_minutes
  end

  test "hours_value and minutes_value" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: 90, date: Date.current)

    assert_equal 1, time_entry.hours_value
    assert_equal 30, time_entry.minutes_value
  end

  test "duration returns Duration object" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: 90, date: Date.current)

    assert_equal "1h 30m", time_entry.duration.to_s
  end

  test "touches card on creation" do
    card = cards(:logo)
    card.update_column(:updated_at, 1.day.ago)

    card.time_entries.create!(total_minutes: 60, date: Date.current)

    assert_in_delta Time.current, card.reload.updated_at, 2.seconds
  end

  test "negative total_minutes allowed for removal" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: -30, date: Date.current)

    assert time_entry.persisted?
    assert_equal(-30, time_entry.total_minutes)
  end

  test "negative entry via accessor" do
    time_entry = cards(:logo).time_entries.build(hours: 0, minutes: 30, date: Date.current)
    time_entry.negative = true
    time_entry.save!

    assert_equal(-30, time_entry.total_minutes)
  end

  test "cannot remove more than total logged" do
    card = cards(:logo)
    total = card.total_minutes

    time_entry = card.time_entries.build(total_minutes: -(total + 1), date: Date.current)

    assert_not time_entry.valid?
    assert time_entry.errors[:base].any?
  end

  test "duration uses absolute value for negative entries" do
    time_entry = cards(:logo).time_entries.create!(total_minutes: -30, date: Date.current)

    assert_equal "30m", time_entry.duration.to_s
  end
end
