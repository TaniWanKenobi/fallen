# frozen_string_literal: true

class AdminWorkshopRsvpSerializer < ApplicationSerializer
  typelize_from WorkshopRsvp
  typelize id: :string
  attributes :email, :slack_username, :slot, :created_at
  attribute(:id) { |rsvp| rsvp.public_id }
end
