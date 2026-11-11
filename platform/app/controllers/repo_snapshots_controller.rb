# The submit popup's repository step: starts a read of the repo (RepoSnapshot, RepoSnapshotJob) and polls it.
# JSON only.
class RepoSnapshotsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { render json: { error: "Too many checks. Wait a minute." }, status: :too_many_requests }

  def create
    project = Project.kept.find_by_public_id!(params[:project_id])
    authorize RepoSnapshot.new(project:)
    snapshot = RepoSnapshot.start(project:, user: current_user, url: params.expect(:url))
    return render(json: { error: "You've checked a lot of times this hour. Try again later." }, status: :too_many_requests) if snapshot == :throttled

    render json: RepoSnapshotSerializer.render(snapshot)
  rescue GitRemote::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def show
    snapshot = RepoSnapshot.find_by_public_id!(params[:id])
    authorize snapshot
    snapshot.read_bom_later
    render json: RepoSnapshotSerializer.render(snapshot)
  end
end
