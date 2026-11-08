require "test_helper"

class DailyGoalsTest < ActionDispatch::IntegrationTest
  test "sets their own daily goal and goes back to the suggested one" do
    sign_in_as users(:member)
    patch daily_goal_path, params: { minutes: 90 }
    assert_redirected_to home_path
    assert_equal 90, users(:member).reload.daily_goal_minutes

    delete daily_goal_path
    assert_nil users(:member).reload.daily_goal_minutes
  end

  test "refuses a goal outside the range" do
    sign_in_as users(:member)
    patch daily_goal_path, params: { minutes: DailyGoal::CUSTOM_MINUTES.max + 1 }
    assert_nil users(:member).reload.daily_goal_minutes
    assert session[:inertia_errors].key?(:daily_goal_minutes)
  end

  test "refuses something that isn't a number instead of clearing the goal" do
    users(:member).update!(daily_goal_minutes: 90)
    sign_in_as users(:member)
    patch daily_goal_path, params: { minutes: "lots" }
    assert_equal 90, users(:member).reload.daily_goal_minutes
  end

  test "an admin browsing as someone can't change it" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:member))
    patch daily_goal_path, params: { minutes: 90 }
    assert_nil users(:member).reload.daily_goal_minutes
  end

  test "needs a session" do
    patch daily_goal_path, params: { minutes: 90 }
    assert_response :redirect
    assert_nil users(:member).reload.daily_goal_minutes
  end
end
