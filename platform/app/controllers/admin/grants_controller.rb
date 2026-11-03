# Design funding (GrantPayout): what approved submissions are owed, sending it through HCB, and connecting HCB.
class Admin::GrantsController < Admin::ApplicationController
  include OauthState

  TABS = %w[unsent sent all].freeze

  def index
    tab = TABS.include?(params[:tab]) ? params[:tab] : "unsent"
    scope = policy_scope([ :admin, GrantPayout ])
    rows = (tab == "unsent" ? scope.unsent : tab == "sent" ? scope.where(status: "sent") : scope).order(created_at: tab == "unsent" ? :asc : :desc)
    connection = HcbConnection.current

    render inertia: "Admin/Grants/Index", props: {
      tab:,
      hcb: {
        configured: Hcb.configured?, connected: connection&.connected? || false, expires_at: connection&.token_expires_at,
        connected_by: connection && PersonSerializer.render(connection.connected_by), writes: Hcb.writes_allowed?,
        automatic: Flipper.enabled?(GrantPayout::FLAG), flag: GrantPayout::FLAG.to_s
      },
      totals: InertiaRails.defer(group: "table") { { unsent: scope.unsent.sum(:amount_cents), sent: scope.where(status: "sent").sum(:amount_cents), unsent_count: scope.unsent.count } },
      **deferred_table(rows.includes(:sent_by, :user, submission: :project), AdminGrantPayoutSerializer, :payouts)
    }
  end

  def send_now
    payout = find_and_authorize(:send_now?)
    GrantPayoutJob.perform_later(payout, by_hand: true)
    redirect_back fallback_location: admin_grants_path, notice: "Sending #{Money.format(payout.amount_cents)} to #{payout.user.email}. Reload in a moment."
  end

  def retry
    find_and_authorize(:retry?).retry!
    redirect_back fallback_location: admin_grants_path, notice: "Back to unsent. Send it again when you're sure HCB didn't get it."
  end

  def mark_sent
    payout = find_and_authorize(:mark_sent?)
    payout.mark_sent!(by: true_user, reference: params[:reference])
    redirect_back fallback_location: admin_grants_path, notice: "Marked as sent."
  end

  # "Connect HCB": the program's organization token, which every payout uses.
  def connect
    authorize [ :admin, GrantPayout ], :connect?
    return redirect_to(admin_grants_path, alert: "Set HCB_CLIENT_ID, HCB_CLIENT_SECRET and HCB_ORGANIZATION_ID first.") unless Hcb.configured?

    redirect_to Hcb.authorize_url(hcb_callback_admin_grants_url, issue_oauth_state), allow_other_host: true
  end

  def callback
    authorize [ :admin, GrantPayout ], :connect?
    return redirect_to(admin_grants_path, alert: "Connecting HCB failed (state mismatch). Try again.") unless consume_oauth_state(params[:state])
    return redirect_to(admin_grants_path, alert: "Connecting HCB was cancelled.") if params[:error].present?

    HcbConnection.connect!(Hcb.exchange_code(params[:code], hcb_callback_admin_grants_url), by: true_user)
    redirect_to admin_grants_path, notice: "HCB connected."
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    redirect_to admin_grants_path, alert: "Connecting HCB failed: #{e.message}"
  end

  private

  def find_and_authorize(action)
    payout = GrantPayout.find_by_public_id!(params[:id])
    authorize [ :admin, payout ], action
    payout
  end
end
