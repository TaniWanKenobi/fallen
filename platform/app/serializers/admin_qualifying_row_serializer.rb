# frozen_string_literal: true

# Admin-only. Someone on /admin/qualifying, with where they stand (QualifyingPace.with_status) and projected finish, the XP their team's
# on-track line is at (`lines`, by pet), and when they last journaled and how much lately (QualifyingStats.journal_activity).
class AdminQualifyingRowSerializer < AdminUserSerializer
  typelize status: "'on_track' | 'behind' | 'off_track' | 'qualified' | 'not_started'", line_xp: :number, projected_xp: :number, recent_minutes: :number, total_minutes: :number, hours_to_qualify: :number,
           last_journal_at: [ :string, nullable: true ]

  attribute(:status, &:pace_status)
  attribute(:line_xp) { |user| params[:lines].fetch(user.pet) }
  attribute(:projected_xp, &:pace_projected)
  attribute(:recent_minutes) { |user| params[:recent_minutes].fetch(user.id, 0) }
  attribute(:total_minutes) { |user| params[:total_minutes].fetch(user.id, 0) }
  # Every hour they've logged plus the rest with their team's reward in full, as the page's average counts it.
  attribute(:hours_to_qualify) { |user| QualifyingStats.hours_to_qualify(user, params[:total_minutes].fetch(user.id, 0), params[:day]).round(1) }
  attribute(:last_journal_at) { |user| params[:last_journals][user.id] }
  # From the status, so a row never asks whether a project is approved.
  attribute(:pet_form) { |user| user.hatched? ? Evolution.stage(user.xp) { user.pace_status == "qualified" } : 0 }
end
