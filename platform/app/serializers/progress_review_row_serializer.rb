# frozen_string_literal: true

# A journal review already made, for reviewers: on the decided tabs of /admin/journal-reviews and in a project's
# history on its review page.
class ProgressReviewRowSerializer < ApplicationSerializer
  typelize_from ProgressReview
  typelize id: :string, project_id: :string, project_title: :string, verdict: "'approved' | 'check_back' | 'dismissed'",
           due_reason: "'requested' | 'added' | 'first' | 'approved' | 'check_back' | 'submitted' | null", journal_notes: "Record<string, string>",
           reviewer: "{ id: string; name: string; avatar: string } | null"
  attributes :verdict, :due_reason, :journal_notes, :feedback, :logged_minutes, :created_at
  attribute(:id) { |review| review.public_id }
  attribute(:project_id) { |review| review.project.public_id }
  attribute(:project_title) { |review| review.project.title }
  one :reviewer, resource: PersonSerializer
end
