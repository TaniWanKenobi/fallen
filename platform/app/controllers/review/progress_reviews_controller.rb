# Editing the feedback on a journal review that's already gone out (ProgressReview). The project page shows the new
# text and the reply in the project's thread is rewritten, with nothing to say it changed.
class Review::ProgressReviewsController < Review::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def update
    review = ProgressReview.find_by_public_id!(params[:id])
    authorize [ :review, review ]
    back = journal_review_project_path(review.project)
    if review.update(feedback: params.expect(:feedback).to_s.strip.presence)
      redirect_back fallback_location: back, status: :see_other
    else
      redirect_back fallback_location: back, inertia: { errors: review.errors.to_hash(true).transform_values(&:to_sentence) }
    end
  end

  private

  def reviewer?(user) = user.reviews_journals?
end
