# frozen_string_literal: true

# A project in the journal review queue, or on its starred or AI-flagged tabs (/admin/journal-reviews).
class ProgressRowSerializer < ApplicationSerializer
  typelize_from ProgressStatus
  typelize id: :string, project_title: :string, owner: "{ id: string; name: string; avatar: string }",
           due_reason: "'requested' | 'added' | 'first' | 'approved' | 'check_back' | 'submitted' | null", due_label: [ :string, nullable: true ],
           claimed_by: "{ id: string; name: string; avatar: string } | null", flagged_by: "{ id: string; name: string; avatar: string } | null",
           starred_by: "{ id: string; name: string; avatar: string } | null", starred: :boolean, flagged: :boolean
  attributes :due_reason, :due_since, :logged_minutes, :approvals_count, :reviews_count, :claim_expires_at, :flagged_at, :flag_reason, :starred_at
  attribute(:id) { |status| status.project.public_id }
  attribute(:project_title) { |status| status.project.title }
  attribute(:due_label, &:due_label)
  attribute(:flagged, &:flagged?)
  attribute(:starred, &:starred?)
  attribute(:owner) { |status| PersonSerializer.render(status.project.user) }
  one :claimed_by, resource: PersonSerializer
  one :flagged_by, resource: PersonSerializer
  one :starred_by, resource: PersonSerializer
end
