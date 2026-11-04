# Ticking off (or un-ticking) something a journal review asked the team to fix, on the project page.
class ReviewTodosController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def update
    todo = ReviewTodo.find_by_public_id!(params[:id])
    authorize todo
    todo.mark(ActiveModel::Type::Boolean.new.cast(params.expect(:done)), by: current_user)
    redirect_to project_path(todo.project), status: :see_other
  end
end
