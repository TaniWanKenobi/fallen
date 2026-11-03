# /review, the design review queue. Design reviewers and admins only (Constraints::DesignReviewer routes it,
# require_reviewer! checks again). Decisions are made as true_user, the person at the keyboard.
class Review::ApplicationController < ApplicationController
  before_action :require_reviewer!

  private

  def pundit_user = true_user

  def require_reviewer!
    raise ActionController::RoutingError, "Not Found" unless true_user&.reviews_designs?
  end
end
