# frozen_string_literal: true

# Journal review (/admin/journal-reviews): reviewers and admins. Nobody reviews a project they're on; only admins
# clear an AI flag or add a project to the queue by hand.
class Review::ProgressStatusPolicy < ApplicationPolicy
  def index? = reviewer?
  def show? = reviewer?
  def next? = reviewer?
  def decide? = reviewer? && record.due? && !record.flagged? && !record.project.on_team?(user)
  def claim? = decide?
  def flag? = reviewer? && !record.flagged?
  def unflag? = admin? && record.flagged?
  # Putting a project in the queue by its link, whatever its hours.
  def add? = admin?
  # Not their own project: a star says a reviewer picked it out.
  def star? = reviewer? && !record.project.on_team?(user)

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.reviews_journals? ? scope.all : scope.none
  end

  private

  def reviewer? = user&.reviews_journals? || false
end
