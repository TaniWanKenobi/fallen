# XP a journal review's second "check back" in a row holds back from one person until a reviewer sees the fixes (the
# first only warns): a share (ProgressReview::XP_HELD_SHARE) of what their journals on the project earned since the
# review before. It's two entries in the XP ledger, never edited: a negative `review_hold` when held and a matching
# `review_release` when a journal review approves the project, its design is approved or the project is deleted, so a
# week's XP that was already counted stays as it was.
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

  # Holds the share of each author's journal XP on the project since the previous review. Nothing for someone whose
  # share rounds to nothing.
  def self.hold_for(review, since:)
    journals = review.project.journals.kept.where.not(duration_minutes: nil)
    journals = journals.where(created_at: since..) if since
    earned = XpEntry.journals.kept.where(source_type: "Journal", source_id: journals.select(:id)).group(:user_id).sum(:amount)
    users = User.where(id: earned.keys).index_by(&:id)
    earned.filter_map do |user_id, xp|
      amount = (xp * ProgressReview::XP_HELD_SHARE).floor
      next if amount <= 0

      hold = create!(project: review.project, progress_review: review, user: users.fetch(user_id), amount:)
      hold.xp_entries.create!(user: hold.user, kind: "review_hold", amount: -amount, day: hold.user.local_date)
      hold
    end
  end

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
