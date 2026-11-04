# One thing a journal review's "check back" asked the team to fix. The team ticks it off on the project page when
# they've done it; the next reviewer sees what was ticked, can reopen one that isn't really fixed, and approving
# resolves them all (ProgressReview).
# == Schema Information
#
# Table name: review_todos
#
#  id                 :bigint           not null, primary key
#  body               :text             not null
#  done_at            :datetime
#  position           :integer          default(0), not null
#  resolved_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  done_by_id         :bigint
#  progress_review_id :bigint           not null
#  project_id         :bigint           not null
#
# Indexes
#
#  index_review_todos_on_done_by_id          (done_by_id)
#  index_review_todos_on_progress_review_id  (progress_review_id)
#  index_review_todos_on_project_id          (project_id)
#  index_review_todos_unresolved             (project_id) WHERE (resolved_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (done_by_id => users.id)
#  fk_rails_...  (progress_review_id => progress_reviews.id)
#  fk_rails_...  (project_id => projects.id)
#
class ReviewTodo < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :rtd
  has_paper_trail

  MAX_BODY = 500
  MAX_PER_REVIEW = 10

  belongs_to :project
  belongs_to :progress_review
  belongs_to :done_by, class_name: "User", optional: true

  validates :body, presence: true, length: { maximum: MAX_BODY }

  scope :unresolved, -> { where(resolved_at: nil) }
  scope :ordered, -> { order(:created_at, :position, :id) }

  def done? = done_at.present?

  def mark(done, by:)
    update!(done_at: done ? Time.current : nil, done_by: done ? by : nil)
  end
end
