# frozen_string_literal: true

# Journals are mirrored into Slack as the person, so they need Slack connected or skipped (User#slack_ready?). A
# project does not: onboarding makes one before that, and its thread is posted once it is (PostProjectToSlackJob).
# Everyone on the team edits the project and invites people; only the owner takes people off or deletes it, and only
# once nobody else is on it or has journals on it, since deleting takes its journals' XP back. Someone taken off the
# team keeps theirs. Any Faller signed in with Hack Club Auth can look at a project; its design submission, what
# reviewers said and its journals' timelapses stay with the people on it and staff (show_private?).
class ProjectPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = involved? || staff? || verified?
  def show_private? = involved? || staff?
  def create? = user.present?
  def update? = teammate?
  def destroy? = owner? && record.solo? && !record.journals.kept.where.not(user_id: record.user_id).exists?
  def invite? = teammate?
  def remove_teammate? = owner?
  # Asking for a journal review (ProgressStatus.request), when there's nothing stopping it.
  def request_review? = teammate? && record.kept? && ProgressStatus.request_blocker(record).nil?
  # The owner can leave once there is someone to hand the project to.
  def leave? = teammate? && !(owner? && record.solo?)
  def join? = user.present? && !teammate? && !record.team_full?
  # The join link's page: holding the link is the permission, so it shows even before signing in.
  def show_invitation? = true

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.involving(user)
  end

  private

  def teammate? = record.on_team?(user)
  def involved? = teammate? || record.journals.kept.exists?(user: user)
  # Trial accounts (not yet through Hack Club Auth) only see their own.
  def verified? = user.present? && !user.trial?
end
