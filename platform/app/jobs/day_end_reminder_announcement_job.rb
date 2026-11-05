# Posts the day-end reminder opt-in (SlackMessages.day_end_reminder_announcement) in `channel`, the announcements
# channel (#fallen-bulletin). Run by hand once when the feature launches; running it again posts it again. The bot
# has to be in the channel.
class DayEndReminderAnnouncementJob < ApplicationJob
  queue_as :slack

  def perform(channel)
    return unless SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: channel, **SlackMessages.day_end_reminder_announcement)
  end
end
