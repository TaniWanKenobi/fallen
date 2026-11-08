# Changing their pronouns from Settings > Profile (components/settings/ProfileSection.svelte). Blank clears them.
# Only ever the signed-in user's own.
class PronounsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #update authorizes explicitly

  def update
    authorize current_user, :edit_self?
    if current_user.update(pronouns: params[:pronouns].to_s)
      redirect_back fallback_location: settings_path
    else
      redirect_back fallback_location: settings_path, alert: current_user.errors.full_messages.first
    end
  end
end
