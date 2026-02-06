require "test_helper"

class Cards::TimeEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_card_time_entry_path(cards(:logo))

    assert_response :success
  end

  test "create" do
    assert_difference -> { cards(:logo).time_entries.count }, +1 do
      post card_time_entries_path(cards(:logo)), params: { time_entry: { hours: 1, minutes: 30, date: Date.current } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal 90, TimeEntry.last.total_minutes
  end

  test "create with only minutes" do
    assert_difference -> { cards(:logo).time_entries.count }, +1 do
      post card_time_entries_path(cards(:logo)), params: { time_entry: { minutes: 45, date: Date.current } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal 45, TimeEntry.last.total_minutes
  end

  test "create with commit=remove stores negative total_minutes" do
    assert_difference -> { cards(:logo).time_entries.count }, +1 do
      post card_time_entries_path(cards(:logo)), params: { commit: "remove", time_entry: { hours: 0, minutes: 30, date: Date.current } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal(-30, TimeEntry.last.total_minutes)
  end

  test "create removal rejected when exceeds total" do
    card = cards(:logo)
    total = card.total_minutes

    assert_no_difference -> { card.time_entries.count } do
      post card_time_entries_path(card), params: { commit: "remove", time_entry: { hours: 0, minutes: total + 1, date: Date.current } }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test "update own time entry" do
    put card_time_entry_path(cards(:logo), time_entries(:logo_review_time)), params: { time_entry: { hours: 1, minutes: 0 } }, as: :turbo_stream

    assert_response :success
    assert_equal 60, time_entries(:logo_review_time).reload.total_minutes
  end

  test "update another user's time entry is forbidden" do
    assert_no_changes -> { time_entries(:logo_design_time).reload.total_minutes } do
      put card_time_entry_path(cards(:logo), time_entries(:logo_design_time)), params: { time_entry: { hours: 16, minutes: 39 } }, as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "destroy own time entry" do
    assert_difference -> { TimeEntry.count }, -1 do
      delete card_time_entry_path(cards(:logo), time_entries(:logo_review_time)), as: :turbo_stream
    end

    assert_response :success
  end

  test "destroy another user's time entry is forbidden" do
    assert_no_difference -> { TimeEntry.count } do
      delete card_time_entry_path(cards(:logo), time_entries(:logo_design_time)), as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "index as JSON" do
    card = cards(:logo)

    get card_time_entries_path(card), as: :json

    assert_response :success
    assert_equal card.time_entries.count, @response.parsed_body.count
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_difference -> { card.time_entries.count }, +1 do
      post card_time_entries_path(card), params: { time_entry: { hours: 0, minutes: 45, date: Date.current } }, as: :json
    end

    assert_response :created
    assert_equal card_time_entry_path(card, TimeEntry.last, format: :json), @response.headers["Location"]
  end

  test "show as JSON" do
    time_entry = time_entries(:logo_review_time)

    get card_time_entry_path(time_entry.card, time_entry), as: :json

    assert_response :success
    assert_equal time_entry.id, @response.parsed_body["id"]
    assert_equal time_entry.total_minutes, @response.parsed_body["total_minutes"]
  end

  test "update as JSON" do
    time_entry = time_entries(:logo_review_time)

    put card_time_entry_path(cards(:logo), time_entry), params: { time_entry: { hours: 1, minutes: 30 } }, as: :json

    assert_response :success
    assert_equal 90, time_entry.reload.total_minutes
  end

  test "destroy as JSON" do
    time_entry = time_entries(:logo_review_time)

    delete card_time_entry_path(cards(:logo), time_entry), as: :json

    assert_response :no_content
    assert_not TimeEntry.exists?(time_entry.id)
  end
end
