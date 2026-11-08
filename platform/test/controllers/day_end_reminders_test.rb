require "test_helper"

class DayEndRemindersTest < ActionDispatch::IntegrationTest
  test "the dashboard box turns the Slack ping on and off" do
    sign_in_as users(:member)
    post day_end_reminder_path
    assert_redirected_to home_path
    assert users(:member).reload.day_end_reminder.present?

    post day_end_reminder_path
    assert_equal 1, DayEndReminder.where(user: users(:member)).count

    delete day_end_reminder_path
    assert_nil users(:member).reload.day_end_reminder
  end

  test "needs a Slack id to mention" do
    users(:member).update!(slack_id: nil)
    sign_in_as users(:member)
    post day_end_reminder_path
    assert_nil users(:member).reload.day_end_reminder
    assert flash[:alert].present?
  end

  test "needs a session" do
    post day_end_reminder_path
    assert_response :redirect
    assert_not DayEndReminder.exists?(user: users(:member))
  end
end
