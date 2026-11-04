# The workshop sign-up page (WorkshopRsvp), linked only from the invite email. No account needed.
class WorkshopRsvpsController < ApplicationController
  allow_unauthenticated_access only: %i[new create] # Signing up needs no account
  allow_trial_access only: %i[new create] # Signing up needs no account
  skip_after_action :verify_authorized # No index action (Rails raises on `except: :index` otherwise); both actions still authorize
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  def new
    authorize WorkshopRsvp
    render inertia: "WorkshopRsvps/New", props: {
      title: WorkshopRsvp::TITLE, slots: WorkshopRsvp.upcoming_slots,
      signed_up: flash[:workshop_rsvp], email: current_user&.email
    }
  end

  def create
    authorize WorkshopRsvp
    rsvp = WorkshopRsvp.sign_up(**params.expect(workshop_rsvp: %i[email slack_username slot]).to_h.symbolize_keys)
    return inertia_errors(rsvp, fallback_location: workshop_rsvp_path) if rsvp.errors.any?

    flash[:workshop_rsvp] = rsvp.slot
    redirect_to workshop_rsvp_path
  end
end
