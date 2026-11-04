# frozen_string_literal: true

# /workshops/rsvp: anyone may sign up, with or without an account.
class WorkshopRsvpPolicy < ApplicationPolicy
  def create? = true
end
