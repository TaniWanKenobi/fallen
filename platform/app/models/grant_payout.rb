# The funding an approved design submission earns, sent to the person who submitted it as an HCB card grant: their
# first one makes the card, later ones top it up. With the hcb_auto_grants flag on, GrantPayoutJob sends it as soon
# as the review is in; otherwise (or when sending fails) an admin sends it on HCB and marks it here (/admin/grants).
#
# Sending is "at most once": the row is marked "sending" and committed before HCB is called, so a crash or a timeout
# mid-call leaves it failed for an admin to check on HCB, never sent twice.
# == Schema Information
#
# Table name: grant_payouts
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  error             :text
#  hcb_reference     :string
#  sent_at           :datetime
#  status            :string           default("pending"), not null
#  via               :string           default("auto"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  hcb_grant_card_id :bigint
#  sent_by_id        :bigint
#  submission_id     :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_grant_payouts_on_hcb_grant_card_id  (hcb_grant_card_id)
#  index_grant_payouts_on_sent_by_id         (sent_by_id)
#  index_grant_payouts_on_status             (status)
#  index_grant_payouts_on_submission_id      (submission_id)
#  index_grant_payouts_on_user_id            (user_id)
#  index_grant_payouts_one_per_submission    (submission_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (hcb_grant_card_id => hcb_grant_cards.id)
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (submission_id => submissions.id)
#  fk_rails_...  (user_id => users.id)
#
class GrantPayout < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :gpo
  has_paper_trail

  STATUSES = %w[pending sending sent failed].freeze
  FLAG = :hcb_auto_grants

  belongs_to :submission
  belongs_to :user
  belongs_to :hcb_grant_card, optional: true
  belongs_to :sent_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :via, inclusion: { in: %w[auto manual] }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :unsent, -> { where(status: %w[pending failed sending]) }

  def self.automatic? = Flipper.enabled?(FLAG) && Hcb.configured? && HcbConnection.current&.connected?

  STATUSES.each { |status| define_method(:"#{status}?") { self.status == status } }

  def send!
    return unless GrantPayout.where(id:, status: "pending").update_all(status: "sending", error: nil, updated_at: Time.current) == 1

    reload
    card = user.hcb_grant_cards.active.first
    if card
      Hcb.topup_card_grant(card.hcb_id, amount_cents:)
      card.update!(amount_cents: card.amount_cents + amount_cents, last_synced_at: Time.current)
    else
      data = Hcb.create_card_grant(amount_cents:, email: user.email, purpose: HcbGrantCard::PURPOSE)
      card = HcbGrantCard.create!(user:, hcb_id: data[:id], email: data[:email] || user.email, amount_cents:, last_synced_at: Time.current)
    end
    update!(status: "sent", via: "auto", hcb_grant_card: card, hcb_reference: card.hcb_id, sent_at: Time.current)
  rescue Hcb::Error, KeyError => e
    update!(status: "pending", error: e.message)
  rescue StandardError => e
    update!(status: "failed", error: "#{e.class}: #{e.message.truncate(500)}. It may have reached HCB: check there before sending again.")
    Sentry.capture_exception(e)
  end

  # An admin sent it on HCB by hand, or checked that a failed send went through.
  def mark_sent!(by:, reference:)
    raise ActiveRecord::RecordInvalid, self if sent?

    update!(status: "sent", via: "manual", sent_by: by, hcb_reference: reference.to_s.strip.presence, sent_at: Time.current, error: nil)
  end

  # After an admin checked HCB and the failed send didn't go through.
  def retry!
    update!(status: "pending", error: nil) if failed? || sending?
  end
end
