# The dashboard's "Want to edit your goal?" (components/EditGoalModal.svelte): their own minutes a day in place of the
# suggested goal (DailyGoal), or back to it. Only ever the signed-in user's own.
class DailyGoalsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; each action authorizes explicitly

  def update
    authorize current_user, :edit_self?
    if current_user.update(daily_goal_minutes: params.require(:minutes))
      redirect_back fallback_location: home_path
    else
      inertia_errors current_user, fallback_location: home_path
    end
  end

  def destroy
    authorize current_user, :edit_self?
    current_user.update!(daily_goal_minutes: nil)
    redirect_back fallback_location: home_path
  end
end
