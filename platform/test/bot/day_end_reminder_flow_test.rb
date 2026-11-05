require "test_helper"

class DayEndReminderFlowTest < ActiveSupport::TestCase
  test "opting in and out from the announcement answers only the person who pressed" do
    with_fake_slack do |slack|
      press("on")
      assert DayEndReminder.exists?(user: users(:member))
      press("on")
      assert_equal 1, DayEndReminder.where(user: users(:member)).count, "pressing twice keeps one"
      assert_match "You're in!", slack.calls_to(:chat_postEphemeral).first[:text]

      press("off")
      assert_not DayEndReminder.exists?(user: users(:member))
      assert_equal [ "CLULU", "U0MEMBER" ], slack.calls_to(:chat_postEphemeral).last.values_at(:channel, :user)
      assert_empty slack.calls_to(:chat_postMessage)
    end
  end

  test "someone who hasn't picked a pet is kept, and told pings start once they have" do
    users(:newcomer).update_columns(slack_id: "U0NEWCOMER")
    with_fake_slack do |slack|
      press("on", user: "U0NEWCOMER")
      assert DayEndReminder.exists?(user: users(:newcomer))
      assert_match "once you've finished signing up on Fallen and picked your pet", slack.calls_to(:chat_postEphemeral).sole[:text]
    end
  end

  test "someone without an account is told to sign up" do
    with_fake_slack do |slack|
      press("on", user: "U0STRANGER")
      assert_equal 0, DayEndReminder.count
      assert_match "Sign up for Fallen first", slack.calls_to(:chat_postEphemeral).sole[:text]
    end
  end

  private

  def press(choice, user: "U0MEMBER")
    SlackBot.handle(:interaction, { "type" => "block_actions", "user" => { "id" => user }, "channel" => { "id" => "CLULU" }, "trigger_id" => "t",
                                    "response_url" => "https://hooks.slack.test/r", "actions" => [ { "action_id" => "day_end_reminder:#{choice}" } ] })
  end
end
