# frozen_string_literal: true

# /admin/workshop-rsvps: admins read every sign-up, with emails.
class Admin::WorkshopRsvpPolicy < ApplicationPolicy
  def index? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
