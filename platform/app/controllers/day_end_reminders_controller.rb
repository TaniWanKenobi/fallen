# The "Ping me on Slack to lock in" box on the dashboard: the same opt-in as the buttons in #fallen-bulletin
# (DayEndReminderAction). Only ever the signed-in user's own.
class DayEndRemindersController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; each action authorizes explicitly

  def create
    authorize current_user, :edit_self?
    return redirect_back(fallback_location: home_path, alert: "Connect Slack first, so the ping can reach you.") unless current_user.remindable?

    DayEndReminder.set(current_user, true)
    redirect_back fallback_location: home_path
  end

  def destroy
    authorize current_user, :edit_self?
    DayEndReminder.set(current_user, false)
    redirect_back fallback_location: home_path
  end
end
