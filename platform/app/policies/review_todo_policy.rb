# frozen_string_literal: true

# The team ticks off what a journal review asked them to fix, until a reviewer resolves it.
class ReviewTodoPolicy < ApplicationPolicy
  def update? = record.resolved_at.nil? && record.project.kept? && record.project.on_team?(user)
end
