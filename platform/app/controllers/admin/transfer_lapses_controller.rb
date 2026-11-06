# /admin/transfers/:id/lapse: the Lapse and Lookout recordings behind a transfer, checked before it's approved
# (TransferLapseReview).
class Admin::TransferLapsesController < Admin::ApplicationController
  # Reviewers work transfers too; the route constraint and Admin::ProjectTransferPolicy decide who gets in.
  skip_before_action :require_admin!, only: %i[show update annotations]
  before_action :require_transfer_reviewer!, only: %i[show update annotations]
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def show
    transfer = find_and_authorize(:lapse?)

    render inertia: "Admin/TransferLapses/Show", props: {
      transfer: AdminTransferLapseSerializer.render(transfer, counted: counted_elsewhere(transfer)),
      configured: Hackatime.configured?,
      can: { review: policy([ :admin, transfer ]).review_lapse? }
    }
  end

  def update
    transfer = find_and_authorize(:review_lapse?)
    fields = params.expect(lapse: [ :hackatime_user_id, :hackatime_projects ])

    if transfer.request_lapse(user_id: fields[:hackatime_user_id], projects: fields[:hackatime_projects].to_s)
      FetchTransferLapseJob.perform_later(transfer) if transfer.lapse_requested?
      redirect_to admin_transfer_lapse_path(transfer), notice: transfer.lapse_requested? ? "Looking up their recordings." : "Cleared."
    else
      inertia_errors(transfer, fallback_location: admin_transfer_lapse_path(transfer))
    end
  end

  # Saves as the reviewer goes, from fetch, so the answer is JSON.
  def annotations
    transfer = find_and_authorize(:review_lapse?)
    annotations = JSON.parse(params.require(:annotations))
    return head :unprocessable_content unless annotations.is_a?(Hash) && transfer.annotate_lapse(annotations)

    render json: { lapse_seconds: transfer.lapse_seconds }
  rescue JSON::ParserError
    head :unprocessable_content
  end

  private

  def require_transfer_reviewer!
    raise ActionController::RoutingError, "Not Found" unless current_user&.reviews_transfers?
  end

  def find_and_authorize(query)
    ProjectTransfer.find_by_public_id!(params[:transfer_id]).tap { authorize [ :admin, it ], query }
  end

  # Where else each recording was counted: Fallen journals that picked the timelapse, and other transfers whose review
  # found it. { key => ["Journal on <project>", "Transfer xfr_…"] }
  def counted_elsewhere(transfer)
    keys = Array(transfer.lapse_recordings).pluck("key")
    return {} if keys.empty?

    lapse_ids = keys.filter_map { it.delete_prefix("lapse:") if it.start_with?("lapse:") }
    journals = LapseTimelapse.joins(journal: :project).where(lapse_id: lapse_ids).where(journals: { discarded_at: nil })
                             .pluck(:lapse_id, "projects.title").map { |id, title| [ "lapse:#{id}", "a journal on #{title}" ] }
    transfers = ProjectTransfer.kept.where.not(id: transfer.id).where.not(lapse_recordings: nil)
                               .where("lapse_recordings @> ANY (ARRAY[?]::jsonb[])", keys.map { [ { key: it } ].to_json })
                               .pluck(:id, :lapse_recordings)
                               .flat_map { |id, recordings| (recordings.pluck("key") & keys).map { [ it, "transfer #{ProjectTransfer.new(id:).public_id}" ] } }
    (journals + transfers).group_by(&:first).transform_values { it.map(&:last) }
  end
end
