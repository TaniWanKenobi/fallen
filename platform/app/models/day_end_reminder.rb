# Someone who asked, from the button on the announcement in #fallen-bulletin (DayEndReminderAnnouncementJob), to be
# pinged in their team's channel when their day is about to end without a journal (DayEndReminderJob). The row is the opt-in;
# the announcement's other button removes it (DayEndReminderAction). `reminded_on` is the last day, on their
# calendar, they were pinged, so they hear it at most once a day.
# == Schema Information
#
# Table name: day_end_reminders
#
#  id          :bigint           not null, primary key
#  reminded_on :date
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_day_end_reminders_on_user_id  (user_id) UNIQUE
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
