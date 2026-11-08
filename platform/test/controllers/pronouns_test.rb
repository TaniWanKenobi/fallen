require "test_helper"

class PronounsTest < ActionDispatch::IntegrationTest
  test "changes and clears their pronouns" do
    sign_in_as users(:member)
    patch pronouns_path, params: { pronouns: "they/them" }
    assert_redirected_to settings_path
    assert_equal "they/them", users(:member).reload.pronouns

    patch pronouns_path, params: { pronouns: "" }
    assert_nil users(:member).reload.pronouns
  end

  test "refuses anything outside the choices" do
    sign_in_as users(:member)
    patch pronouns_path, params: { pronouns: "anything else" }
    assert_nil users(:member).reload.pronouns
    assert flash[:alert].present?
  end

  test "an admin browsing as someone can't change them" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:member))
    patch pronouns_path, params: { pronouns: "she/her" }
    assert_nil users(:member).reload.pronouns
  end

  test "needs a session" do
    patch pronouns_path, params: { pronouns: "she/her" }
    assert_response :redirect
    assert_nil users(:member).reload.pronouns
  end
end
