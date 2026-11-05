# Redraws one day-end ping (SlackMessages.day_end_reminder) from where its people stand now: crossed off once a
# journal counts for the day, and back on if it stops counting (XpEntry, DayEndReminder.journal_changed).
# chat.update keeps the pet the message was posted as, and never notifies the people mentioned again.
class DayEndReminderPingJob < ApplicationJob
  queue_as :slack
  # Two journals landing at once each redraw the whole message; one at a time, the last always shows both.
  limits_concurrency to: 1, key: ->(channel, ts) { "day_end_ping:#{channel}:#{ts}" }, duration: 1.minute

  def perform(channel, ts)
    reminders = DayEndReminder.pinged_in(channel, ts).includes(:user).order(:id).to_a
    return if reminders.empty?

    pet = reminders.first.user.pet
    statuses = DayEndReminder.statuses(reminders)
    still_to_go = reminders.find { statuses[it] == :pending }
    minutes = still_to_go.minutes_left unless still_to_go.nil? || still_to_go.day_over?
    message = SlackMessages.day_end_reminder(pet, reminders.map { [ it.user.slack_id, statuses[it] ] }, minutes)
    SlackBot.client.chat_update(channel: channel, ts: ts, **message.slice(:text, :blocks))
  rescue Faraday::Error => e
    Rails.error.report(e, handled: true, context: { job: "DayEndReminderPingJob", channel: channel, ts: ts })
  end
end
