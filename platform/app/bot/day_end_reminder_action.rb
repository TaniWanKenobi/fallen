# The buttons on the day-end reminder announcement in #fallen-bulletin (SlackMessages.day_end_reminder_announcement).
# action_id is "day_end_reminder:on" or "day_end_reminder:off". Everyone in the channel presses the same message, so
# the answer is only to the person who pressed, and the message stays as it is. Someone with a pet hears it from
# their pet, like the pings; anyone else from the bot.
class DayEndReminderAction < SlackBot::Action
  def call
    return ephemeral(not_linked) unless user

    case arg
    when "on"
      DayEndReminder.create_or_find_by!(user: user)
      # The job only pings people on a team (User.on_a_team), so someone mid-signup is told it starts once they're on one.
      return reply("You're in! I'll start pinging you once you've finished signing up on Fallen and picked your pet: #{SlackMessages.app_url}") unless User.on_a_team.exists?(user.id)

      reply("Let's go! I'll ping you in your team's channel when there are #{DayEndReminder::HOURS_LEFT} hours left in your day and you haven't journaled.")
      # The test copy of the announcement pings them here and now, as if it were already evening.
      DayEndReminderPreviewJob.perform_later(channel_id, [ user.slack_id ]) if value == SlackMessages::DAY_END_PREVIEW
    when "off"
      DayEndReminder.where(user: user).destroy_all
      reply("No more reminders!")
    end
  end

  private

  # Connecting Slack on Fallen (SlackAuthController) needs them signed in first, so the steps say so.
  def not_linked
    url = SlackMessages.app_url
    "I couldn't find a Fallen account linked to your Slack. To link it:\n" \
      "1. Sign in at #{url}\n" \
      "2. Connect your Slack here: #{url}/auth/slack/start\n" \
      "3. Come back and press *Join* again!\n" \
      "No account yet? Sign up at #{url} first."
  end

  def reply(text) = ephemeral(text, **SlackMessages.pet_persona(user.pet))
end
