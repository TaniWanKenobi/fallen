# The buttons on the day-end reminder announcement in #fallen-bulletin (SlackMessages.day_end_reminder_announcement).
# action_id is "day_end_reminder:on" or "day_end_reminder:off". Everyone in the channel presses the same message, so
# the answer is only to the person who pressed, and the message stays as it is.
class DayEndReminderAction < SlackBot::Action
  def call
    return ephemeral("Sign up for Fallen first, then I can remind you: #{SlackMessages.app_url}") unless user

    case arg
    when "on"
      DayEndReminder.create_or_find_by!(user: user)
      # The job only pings people on a team (User.on_a_team), so someone mid-signup is told it starts once they're on one.
      return ephemeral("You're in! I'll start pinging you once you've finished signing up on Fallen and picked your pet: #{SlackMessages.app_url}") unless User.on_a_team.exists?(user.id)

      ephemeral("You're in! I'll ping you in your team's channel when there are #{DayEndReminder::HOURS_LEFT} hours left in your day and you haven't journaled.")
    when "off"
      DayEndReminder.where(user: user).destroy_all
      ephemeral("Okay, no more day-end reminders.")
    end
  end
end
