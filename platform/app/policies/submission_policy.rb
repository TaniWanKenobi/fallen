# frozen_string_literal: true

# Anyone on a project's team sends it for review or takes it back while it waits. Reviewing is
# Review::SubmissionPolicy.
class SubmissionPolicy < ApplicationPolicy
  def create? = record.project.kept? && record.project.on_team?(user) && !user.is_banned?
  def destroy? = record.pending? && record.project.on_team?(user)
end
