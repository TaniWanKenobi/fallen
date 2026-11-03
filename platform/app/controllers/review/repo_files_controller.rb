# One file of a submission's repository, for the review page's file viewers (RepoFile). The first ask queues the
# read and answers 202; the page asks again until the file is there, then downloads it from `url`.
class Review::RepoFilesController < Review::ApplicationController
  # No index action, so both are skipped blanket-style (Rails raises on `except: :index` otherwise); create authorizes.
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def create
    submission = Submission.includes(:repo_snapshot).find_by_public_id!(params[:submission_id])
    authorize [ :review, submission ], :show?
    file = submission.repo_snapshot && RepoFile.request(submission.repo_snapshot, params[:path].to_s)
    return head :not_found unless file

    if file.done?
      render json: { status: "done", size: file.byte_size, url: rails_storage_proxy_path(file.content, disposition: "attachment") }
    elsif file.failed?
      render json: { status: "failed", error: file.error }
    else
      render json: { status: "pending" }, status: :accepted
    end
  end
end
