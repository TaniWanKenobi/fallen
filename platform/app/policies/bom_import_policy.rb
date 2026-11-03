# frozen_string_literal: true

class BomImportPolicy < ApplicationPolicy
  def create? = user.present?
end
