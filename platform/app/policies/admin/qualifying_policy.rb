# frozen_string_literal: true

# /admin/qualifying: who is on track to qualify by the deadline. Admins only.
class Admin::QualifyingPolicy < ApplicationPolicy
  def show? = admin?
end
