# frozen_string_literal: true

class RepoSnapshotPolicy < ApplicationPolicy
  def create? = record.project.kept? && record.project.on_team?(user)
  def show? = record.project.on_team?(user)
end
