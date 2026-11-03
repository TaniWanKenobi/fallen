# The submit popup's checks step (SubmissionChecks), run on what's in the popup. Submitting runs them again.
# JSON only.
class SubmissionChecksController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def create
    project = Project.kept.find_by_public_id!(params[:project_id])
    authorize Submission.new(project:), :create?
    snapshot = project.repo_snapshots.find_by_public_id(params[:snapshot_id])
    items = Array(params[:items]).first(BomItem::MAX_ITEMS).map { |item| BomItem.new(item.permit(*BomItem::FIELDS)) }
    checks = SubmissionChecks.new(project:, snapshot:, made_with: Array(params[:made_with]), screenshots: params[:screenshots].to_i, items:).run
    render json: { checks: }
  end
end
