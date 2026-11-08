# The welcome back's answers (components/welcome-back/WelcomeBack.svelte): pronouns, and whether to turn on the day-end
# ping. Only ever the signed-in user's own.
class WelcomeBacksController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #create authorizes explicitly

  def create
    authorize current_user, :edit_self?
    reminder = ActiveModel::Type::Boolean.new.cast(params[:reminder]) if params.key?(:reminder)
    current_user.welcome_back!(pronouns: params[:pronouns].to_s, reminder: reminder)
    redirect_back fallback_location: home_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: home_path, alert: e.record.errors.full_messages.first
  end
end
