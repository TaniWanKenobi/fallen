# A team asking for a journal review of their project (ProgressStatus.request), from its page.
class ReviewRequestsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_user.id }

  def create
    project = Project.kept.find_by_public_id!(params[:project_id])
    authorize project, :request_review?
    status = ProgressStatus.request(project, user: current_user, note: params[:note])
    if status.errors.empty?
      redirect_to project_path(project), notice: "Asked! A reviewer will read your journals soon and reply in your thread."
    else
      redirect_to project_path(project), alert: status.errors.full_messages.to_sentence
    end
  end
end
