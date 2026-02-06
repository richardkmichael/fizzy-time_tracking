require "application_system_test_case"

class TimeTrackingTest < ApplicationSystemTestCase
  test "add time via popup" do
    sign_in_as(users(:kevin))

    visit card_url(cards(:logo))

    # Existing time should be displayed
    assert_selector "##{dom_id(cards(:logo), :time_logged)}", text: "2h 30m"

    # Open the popup
    find(".card__time-tracking-button").click
    assert_selector "dialog[open]"
    assert_selector ".popup__title", text: "Log time"

    # Fill in the form
    fill_in "time_entry_hours", with: "1"
    fill_in "time_entry_minutes", with: "15"
    fill_in "time_entry_description", with: "Testing the popup"

    # Submit via Add
    find(".btn--time-add", text: "Add").click

    # Popup closes, total updates
    assert_no_selector "dialog[open]"
    assert_selector "##{dom_id(cards(:logo), :time_logged)}", text: "3h 45m"
  end

  test "remove time via popup" do
    sign_in_as(users(:kevin))

    visit card_url(cards(:logo))

    assert_selector "##{dom_id(cards(:logo), :time_logged)}", text: "2h 30m"

    find(".card__time-tracking-button").click
    assert_selector "dialog[open]"

    fill_in "time_entry_hours", with: "0"
    fill_in "time_entry_minutes", with: "30"

    find(".btn--time-remove", text: "Remove").click

    assert_no_selector "dialog[open]"
    assert_selector "##{dom_id(cards(:logo), :time_logged)}", text: "2h"
  end

  test "system comment appears after logging time" do
    sign_in_as(users(:kevin))

    visit card_url(cards(:logo))

    find(".card__time-tracking-button").click
    assert_selector "dialog[open]"

    fill_in "time_entry_hours", with: "0"
    fill_in "time_entry_minutes", with: "45"

    find(".btn--time-add", text: "Add").click

    assert_no_selector "dialog[open]"
    assert_selector ".comment-by-system", text: "added"
  end

  test "log time with keyboard shortcut" do
    sign_in_as(users(:kevin))

    visit card_url(cards(:logo))

    send_keys "l"
    assert_selector "dialog[open]"
    assert_selector ".popup__title", text: "Log time"
  end

  test "popup closes on escape" do
    sign_in_as(users(:kevin))

    visit card_url(cards(:logo))

    find(".card__time-tracking-button").click
    assert_selector "dialog[open]"

    send_keys :escape
    assert_no_selector "dialog[open]"
  end

  test "clock button hidden on closed card" do
    sign_in_as(users(:kevin))

    visit card_url(cards(:shipping))

    assert_no_selector ".card__time-tracking-button"
  end

  private
    def sign_in_as(user)
      visit session_transfer_url(user.identity.transfer_id, script_name: nil)
      assert_selector "h1"
    end
end
