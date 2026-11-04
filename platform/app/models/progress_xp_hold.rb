# XP an older journal review's second "check back" in a row held back from one person until a reviewer saw the fixes.
# Reviews no longer hold XP; the migration that ended it gave back what was held. It's two entries in the XP ledger,
# never edited: a negative `review_hold` when held and a matching `review_release` when it was given back (or the
# design is approved or the project deleted, for any left), so a week's XP that was already counted stays as it was.
# == Schema Information
#
# Table name: progress_xp_holds
#
#  id                    :bigint           not null, primary key
#  amount                :integer          not null
#  released_at           :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  progress_review_id    :bigint           not null
#  project_id            :bigint           not null
#  released_by_review_id :bigint
#  user_id               :bigint           not null
#
# Indexes
#
#  index_progress_xp_holds_on_progress_review_id     (progress_review_id)
#  index_progress_xp_holds_on_project_id             (project_id)
#  index_progress_xp_holds_on_released_by_review_id  (released_by_review_id)
#  index_progress_xp_holds_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (progress_review_id => progress_reviews.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (released_by_review_id => progress_reviews.id)
#  fk_rails_...  (user_id => users.id)
#
class ProgressXpHold < ApplicationRecord
  has_paper_trail

  belongs_to :project
  belongs_to :progress_review
  belongs_to :user
  belongs_to :released_by_review, class_name: "ProgressReview", optional: true
  has_many :xp_entries, as: :source, dependent: :restrict_with_error

  validates :amount, numericality: { only_integer: true, greater_than: 0 }

  scope :held, -> { where(released_at: nil) }

  # Gives back everything held on the project, crediting `by` (a journal review's approval) when that's why.
  def self.release_all(project, by: nil)
    where(project:).held.includes(:user).find_each { it.release!(by:) }
  end

  def release!(by: nil)
    with_lock do
      next if released_at

      update!(released_at: Time.current, released_by_review: by)
      xp_entries.create!(user:, kind: "review_release", amount:, day: user.local_date)
    end
  end
end
