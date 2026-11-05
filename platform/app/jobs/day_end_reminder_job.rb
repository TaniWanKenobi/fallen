# Every 15 minutes: pings, in their team's channel, everyone who opted in (DayEndReminder) whose day has
# DayEndReminder::HOURS_LEFT or less to go on their own clock and who has no journal counting for today. A day counts
# the way the teams' streaks count it (Team#journal_days): a journal with hours, which is what makes its XP entry, so
# someone whose journal is still waiting for hours is pinged too. People due at the same time on the same team share
# a message, up to MENTIONS_PER_MESSAGE each. Each is marked reminded before the message goes out: a missed ping is
# better than a repeated one.
class DayEndReminderJob < ApplicationJob
  # Keeps each ping short enough to read in the channel.
  MENTIONS_PER_MESSAGE = 5
  RATE_LIMIT_RETRIES = 3

  queue_as :slack
  limits_concurrency to: 1, key: "day_end_reminders", duration: 5.minutes

  def perform(now: Time.current)
    return unless SlackBot.configured?

    DayEndReminder.includes(:user).where(user: User.on_a_team.where.not(slack_id: nil)).find_in_batches do |reminders|
      due = unjournaled(reminders.select { it.due?(now) }, now)
      claim(due, now)
      due.group_by { [ it.user.pet, SlackMessages.duration_words(it.minutes_left(now)) ] }.each do |(pet, _), group|
        channel = JoinTeamChannelJob.channel_id(pet) or next
        group.each_slice(MENTIONS_PER_MESSAGE) { ping(channel, pet, it, now) }
      end
    end
  end

  private

  def unjournaled(reminders, now)
    return reminders if reminders.empty?

    today = reminders.to_h { [ it.user_id, it.user.local_date(now) ] }
    counted = XpEntry.journals.kept.where(user_id: today.keys, day: today.values.uniq).distinct.pluck(:user_id, :day).to_set
    reminders.reject { counted.include?([ it.user_id, today[it.user_id] ]) }
  end

  def claim(reminders, now)
    reminders.group_by { it.user.local_date(now) }.each do |day, group|
      DayEndReminder.where(id: group.map(&:id)).update_all(reminded_on: day, updated_at: now)
    end
  end

  # A busy evening posts many pings to one channel at once, so Slack may ask to slow down. Everyone was already
  # claimed, so waiting and trying again is the only way the rest still hear it today.
  def ping(channel, pet, reminders, now)
    message = SlackMessages.day_end_reminder(pet, reminders.map { it.user.slack_id }, reminders.first.minutes_left(now))
    attempts = 0
    begin
      SlackBot.client.chat_postMessage(channel: channel, **message)
    rescue Slack::Web::Api::Errors::TooManyRequestsError => e
      raise if (attempts += 1) > RATE_LIMIT_RETRIES

      sleep(e.retry_after.to_i.clamp(1, 30))
      retry
    end
  rescue Slack::Web::Api::Errors::SlackError, Slack::Web::Api::Errors::TooManyRequestsError => e
    Rails.logger.warn({ event: "day_end_reminder.failed", user_ids: reminders.map(&:user_id), error: e.message }.to_json)
  end
end
