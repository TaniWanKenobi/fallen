require "test_helper"

class WelcomeBacksTest < ActionDispatch::IntegrationTest
  setup { users(:member).update!(welcome_back_seen_at: nil) }

  test "saves pronouns and turns on the Slack ping" do
    sign_in_as users(:member)
    post welcome_back_path, params: { pronouns: "  they/them ", reminder: true }
    assert_redirected_to home_path

    member = users(:member).reload
    assert_equal "they/them", member.pronouns
    assert member.welcome_back_seen_at?
    assert member.day_end_reminder.present?
  end

  test "skipping both leaves the pronouns blank and the ping as it was" do
    DayEndReminder.create!(user: users(:member))
    sign_in_as users(:member)
    post welcome_back_path, params: { pronouns: "" }

    member = users(:member).reload
    assert_nil member.pronouns
    assert member.welcome_back_seen_at?
    assert member.day_end_reminder.present?
  end

  test "no ping without a Slack id to mention" do
    users(:member).update!(slack_id: nil)
    sign_in_as users(:member)
    post welcome_back_path, params: { pronouns: "he/him", reminder: true }
    assert_nil users(:member).reload.day_end_reminder
  end

  test "a yes it can't honour leaves an existing ping alone" do
    DayEndReminder.create!(user: users(:member))
    users(:member).update!(slack_id: nil)
    sign_in_as users(:member)
    post welcome_back_path, params: { pronouns: "he/him", reminder: true }
    assert users(:member).reload.day_end_reminder.present?
  end

  test "pronouns outside the choices are refused" do
    sign_in_as users(:member)
    post welcome_back_path, params: { pronouns: "anything else" }
    assert_nil users(:member).reload.welcome_back_seen_at
    assert flash[:alert].present?
  end

  test "an admin browsing as someone can't answer for them" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:member))
    post welcome_back_path, params: { pronouns: "she/her" }
    assert_nil users(:member).reload.pronouns
  end

  test "needs a session" do
    post welcome_back_path, params: { pronouns: "she/her" }
    assert_response :redirect
    assert_nil users(:member).reload.pronouns
  end
end
