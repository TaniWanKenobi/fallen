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
      due = unjournaled(with_channel(reminders.select { it.due?(now) }), now)
      claim(due, now)
      due.group_by { [ it.user.pet, SlackMessages.duration_words(it.minutes_left(now)) ] }.each do |(pet, _), group|
        channel = JoinTeamChannelJob.channel_id(pet)
        group.each_slice(MENTIONS_PER_MESSAGE) { ping(channel, pet, it, now) }
      end
    end
  end

  private

  # A team with no channel set can't be pinged, so its people are left unmarked for when it is, and someone hears.
  def with_channel(reminders)
    reminders.group_by { it.user.pet }.flat_map do |pet, group|
      next group if JoinTeamChannelJob.channel_id(pet)

      Rails.error.report(ArgumentError.new("SLACK_#{pet.upcase}_CHANNEL_ID is not set"), handled: true, context: { job: "DayEndReminderJob", user_ids: group.map(&:user_id) })
      []
    end
  end

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
  # claimed, so waiting and trying again is the only way the rest still hear it today. Any other failure (a Slack
  # error, a timeout, Slack being down) loses only this message, not the rest of the run, and goes to Sentry: a
  # bad token or channel would otherwise drop every ping, every day, without anyone noticing.
  def ping(channel, pet, reminders, now)
    message = SlackMessages.day_end_reminder(pet, reminders.map { [ it.user.slack_id, :pending ] }, reminders.first.minutes_left(now))
    attempts = 0
    begin
      posted = SlackBot.client.chat_postMessage(channel: channel, **message)
      # Remembered so the message can cross them off as they journal (DayEndReminderPingJob).
      DayEndReminder.where(id: reminders.map(&:id)).update_all(ping_channel_id: posted["channel"], ping_ts: posted["ts"])
    rescue Slack::Web::Api::Errors::TooManyRequestsError => e
      raise if (attempts += 1) > RATE_LIMIT_RETRIES

      sleep(e.retry_after.to_i.clamp(1, 30))
      retry
    end
  rescue Faraday::Error => e
    Rails.error.report(e, handled: true, context: { job: "DayEndReminderJob", channel: channel, user_ids: reminders.map(&:user_id) })
  end
end
