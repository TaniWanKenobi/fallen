# Reviewers' notes on a project (ReviewerNote), written from the review page.
class Review::NotesController < Review::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def create
    submission = Submission.find_by_public_id!(params[:submission_id])
    authorize [ :review, submission ], :note?
    note = submission.project.reviewer_notes.build(submission:, user: true_user, body: params.expect(:body))
    if note.save
      redirect_back fallback_location: review_submission_path(submission)
    else
      inertia_errors(note, fallback_location: review_submission_path(submission))
    end
  end
end
