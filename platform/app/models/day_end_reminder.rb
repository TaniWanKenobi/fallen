# Someone who asked, from the button on the announcement in #fallen-bulletin (DayEndReminderAnnouncementJob), to be
# pinged in their team's channel when their day is about to end without a journal (DayEndReminderJob). The row is the opt-in;
# the announcement's other button removes it (DayEndReminderAction). `reminded_on` is the last day, on their
# calendar, they were pinged, so they hear it at most once a day.
# == Schema Information
#
# Table name: day_end_reminders
#
#  id              :bigint           not null, primary key
#  ping_ts         :string
#  reminded_on     :date
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ping_channel_id :string
#  user_id         :bigint           not null
#
# Indexes
#
#  index_day_end_reminders_on_ping_channel_id_and_ping_ts  (ping_channel_id,ping_ts)
#  index_day_end_reminders_on_user_id                      (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class DayEndReminder < ApplicationRecord
  has_paper_trail

  # How long before midnight, on their own clock, the ping comes.
  HOURS_LEFT = 4

  belongs_to :user

  # Opts `user` in or out, from Slack (DayEndReminderAction) or the site (DayEndRemindersController).
  def self.set(user, on)
    on ? create_or_find_by!(user: user) : where(user: user).destroy_all
  end

  # The people in one ping message (`ping_channel_id`, `ping_ts`), which is redrawn as they journal
  # (DayEndReminderPingJob).
  scope :pinged_in, ->(channel, ts) { where(ping_channel_id: channel, ping_ts: ts) }

  # Where each of `reminders` stands for the day they were pinged: :journaled once a journal counts for it (the way
  # the streak counts it, XpEntry), :pending otherwise. One query for all of them.
  def self.statuses(reminders)
    days = reminders.map(&:reminded_on).compact.uniq
    journaled = XpEntry.journals.kept.where(user_id: reminders.map(&:user_id), day: days).distinct.pluck(:user_id, :day).to_set
    reminders.index_with { journaled.include?([ it.user_id, it.reminded_on ]) ? :journaled : :pending }
  end

  # Redraws the ping `entry`'s person was in that day, now that a journal of theirs counts for it or stopped counting.
  def self.journal_changed(entry)
    reminder = where(user_id: entry.user_id, reminded_on: entry.day).where.not(ping_ts: nil).first or return
    DayEndReminderPingJob.perform_later(reminder.ping_channel_id, reminder.ping_ts)
  end

  # Whether the day they were last pinged for has ended on their clock.
  def day_over?(now = Time.current) = reminded_on.nil? || user.local_date(now) != reminded_on

  # Whether `user`, at `now`, is in the last HOURS_LEFT of their day and has not been pinged for it yet.
  def due?(now = Time.current)
    local = now.in_time_zone(user.timezone)
    local >= midnight(local) - HOURS_LEFT.hours && reminded_on != local.to_date
  end

  # Minutes until midnight on their clock, rounded so the ping reads "about 3.5 hours", not "about 3.8 hours": to the
  # half hour, or under an hour to the quarter.
  def minutes_left(now = Time.current)
    local = now.in_time_zone(user.timezone)
    exact = (midnight(local) - local) / 60.0
    step = exact >= 60 ? 30 : 15
    [ (exact / step).round * step, 15 ].max
  end

  private

  # The start of their next day, which is right across a daylight saving change too.
  def midnight(local) = local.beginning_of_day.advance(days: 1)
end
