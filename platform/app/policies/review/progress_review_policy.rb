# frozen_string_literal: true

# A journal review already sent (ProgressReview): the reviewer who wrote it, or an admin, can edit its feedback.
class Review::ProgressReviewPolicy < ApplicationPolicy
  def update? = (user&.reviews_journals? || false) && record.sent? && (record.reviewer_id == user.id || admin?)
end
