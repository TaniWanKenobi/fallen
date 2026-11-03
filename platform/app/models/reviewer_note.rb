# Something a reviewer wants the next one to know about a project. Kept on the project, so it carries across
# resubmissions. Never shown to the person.
# == Schema Information
#
# Table name: reviewer_notes
#
#  id            :bigint           not null, primary key
#  body          :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  project_id    :bigint           not null
#  submission_id :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_reviewer_notes_on_project_id     (project_id)
#  index_reviewer_notes_on_submission_id  (submission_id)
#  index_reviewer_notes_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (submission_id => submissions.id)
#  fk_rails_...  (user_id => users.id)
#
class ReviewerNote < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :rvn
  has_paper_trail

  belongs_to :project
  belongs_to :submission, optional: true
  belongs_to :user, optional: true

  validates :body, presence: true, length: { maximum: 2_000 }
end
