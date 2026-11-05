# Sends the day-end ping right now into `channel` (a test channel) for the opted-in people whose Slack ids are in
# `slack_ids`, as if it were exactly HOURS_LEFT before midnight for them. Whether they were already pinged or have
# journaled today doesn't matter, so the message always shows. It's a real ping otherwise: it counts as today's for
# them, and journaling crosses them off it (DayEndReminderPingJob). Pressing JOIN on the test copy of the announcement
# runs it for that person in that channel (DayEndReminderAnnouncementJob, preview: true); or run it by hand, e.g.
#   DayEndReminderPreviewJob.perform_now("C0C8CS000JD", ["U0123ABC"])
# Only the people named are mentioned, so trying it out never pings anyone else.
class DayEndReminderPreviewJob < DayEndReminderJob
  def perform(channel, slack_ids)
    return unless SlackBot.configured?

    now = Time.current
    reminders = DayEndReminder.includes(:user).where(user: User.on_a_team.where(slack_id: Array(slack_ids))).to_a
    claim(reminders, now)
    reminders.group_by { it.user.pet }.each do |pet, group|
      group.each_slice(MENTIONS_PER_MESSAGE) { ping(channel, pet, it, ping_time(it.first, now)) }
    end
  end

  private

  # HOURS_LEFT before their next midnight, so the message reads exactly as the evening's does.
  def ping_time(reminder, now)
    local = now.in_time_zone(reminder.user.timezone)
    local.beginning_of_day.advance(days: 1) - DayEndReminder::HOURS_LEFT.hours
  end
end
