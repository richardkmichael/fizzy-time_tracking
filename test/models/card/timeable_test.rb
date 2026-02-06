require "test_helper"

class Card::TimeableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "card has time entries" do
    assert_respond_to cards(:logo), :time_entries
  end

  test "total minutes sums entries" do
    card = cards(:logo)

    assert_equal card.time_entries.sum(:total_minutes), card.total_minutes
  end

  test "total minutes returns zero when no entries" do
    card = cards(:logo)
    card.time_entries.destroy_all

    assert_equal 0, card.total_minutes
  end

  test "total_duration returns Duration object" do
    card = cards(:logo)

    assert_instance_of TimeEntry::Duration, card.total_duration
    assert_equal card.total_minutes, card.total_duration.total_minutes
  end

  test "destroying card destroys time entries" do
    card = cards(:logo)

    assert card.time_entries.any?

    assert_difference -> { TimeEntry.count }, -card.time_entries.count do
      card.destroy!
    end
  end
end
