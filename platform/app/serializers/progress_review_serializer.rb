# frozen_string_literal: true

# A journal review as the project's team sees it on the project page: the outcome and the feedback, not who wrote it.
# == Schema Information
#
# Table name: progress_reviews
#
#  id             :bigint           not null, primary key
#  checks         :jsonb            not null
#  due_reason     :string
#  due_since      :datetime
#  feedback       :text
#  journal_notes  :jsonb            not null
#  logged_minutes :integer          not null
#  verdict        :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
#  reviewer_id    :bigint
#
# Indexes
#
#  index_progress_reviews_on_created_at              (created_at)
#  index_progress_reviews_on_project_id              (project_id)
#  index_progress_reviews_on_project_id_and_verdict  (project_id,verdict)
#  index_progress_reviews_on_reviewer_id             (reviewer_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
class ProgressReviewSerializer < ApplicationSerializer
  typelize_from ProgressReview
  typelize id: :string, verdict: "'approved' | 'check_back'", journal_notes: "Record<string, string>"
  attributes :verdict, :feedback, :journal_notes, :created_at
  attribute(:id) { |review| review.public_id }
end
