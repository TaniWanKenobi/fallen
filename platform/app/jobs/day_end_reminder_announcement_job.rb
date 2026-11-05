# Posts the day-end reminder opt-in (SlackMessages.day_end_reminder_announcement) in `channel`, the announcements
# channel (#fallen-bulletin). Run by hand once when the feature launches; running it again posts it again. The bot
# has to be in the channel. With `preview: true`, for a test channel, pressing JOIN on it pings that person in that
# channel right away, as if it were already evening (DayEndReminderPreviewJob):
#   DayEndReminderAnnouncementJob.perform_now("C0C8CS000JD", preview: true)
class DayEndReminderAnnouncementJob < ApplicationJob
  queue_as :slack

  def perform(channel, preview: false)
    return unless SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: channel, **SlackMessages.day_end_reminder_announcement(preview:))
  end
end
