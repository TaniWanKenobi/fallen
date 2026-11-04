# A sign-up for the Tamagotchi workshop from /workshops/rsvp, a page linked only from the invite email. It needs no
# account and never makes a User, so it stays out of every program number (ProgramStats, QualifyingStats); the
# counts are on /admin/workshop-rsvps instead. Staff email the call link on the day from that page's CSV.
#
# One per email: signing up again moves the person to the slot they picked and keeps the newest Slack name.
# == Schema Information
#
# Table name: workshop_rsvps
#
#  id             :bigint           not null, primary key
#  email          :string           not null
#  slack_username :string
#  slot           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_workshop_rsvps_on_email                (email) UNIQUE
#  index_workshop_rsvps_on_slot_and_created_at  (slot,created_at)
#
class WorkshopRsvp < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :wrs
  has_paper_trail

  TITLE = "Make your own Tamagotchi pet"
  # Each session's start and end, in Eastern time. The page shows them in the viewer's own timezone.
  SLOTS = {
    "nov7" => [ "2026-11-07 14:00", "2026-11-07 16:00" ],
    "nov11" => [ "2026-11-11 18:00", "2026-11-11 20:00" ]
  }.transform_values { |times| times.map { ActiveSupport::TimeZone["America/New_York"].parse(it) } }.freeze

  normalizes :email, with: -> { it.strip.downcase }
  normalizes :slack_username, with: -> { it.strip.delete_prefix("@").presence }

  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP, message: "doesn't look like an email" }
  validates :slack_username, length: { maximum: 80 }
  validates :slot, inclusion: { in: SLOTS.keys, message: "must be one of the workshop times" }
  validate :slot_not_started, if: :will_save_change_to_slot?

  # The sessions for the page: { key:, starts_at:, ends_at: }.
  def self.slots = SLOTS.map { |key, (starts_at, ends_at)| { key:, starts_at:, ends_at: } }

  # The sessions someone can still sign up for: once one starts, its link has already gone out.
  def self.upcoming_slots = slots.reject { started?(it[:key]) }

  def self.started?(key) = SLOTS.fetch(key).first <= Time.current

  # Saves the sign-up, replacing an earlier one from the same email. Returns the record, with errors if invalid.
  def self.sign_up(email: nil, slack_username: nil, slot: nil)
    rsvp = find_or_initialize_by(email: normalize_value_for(:email, email.to_s))
    rsvp.update(slack_username:, slot:)
    rsvp
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private

  def slot_not_started
    errors.add(:slot, :started, message: "has already started") if SLOTS.key?(slot) && self.class.started?(slot)
  end
end
