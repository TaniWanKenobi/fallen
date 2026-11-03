# frozen_string_literal: true

class AdminGrantPayoutSerializer < ApplicationSerializer
  typelize_from GrantPayout
  typelize id: :string, status: "'pending' | 'sending' | 'sent' | 'failed'", via: "'auto' | 'manual'", project_title: :string,
           submission_id: :string, email: :string, recipient: "{ id: string; name: string; avatar: string }",
           sent_by: "{ id: string; name: string; avatar: string } | null"
  attributes :amount_cents, :status, :via, :hcb_reference, :error, :sent_at, :created_at
  attribute(:id) { |payout| payout.public_id }
  attribute(:submission_id) { |payout| payout.submission.public_id }
  attribute(:project_title) { |payout| payout.submission.project.title }
  attribute(:email) { |payout| payout.user.email }
  one :user, key: :recipient, resource: PersonSerializer
  one :sent_by, resource: PersonSerializer
end
