# The review queues in the admin panel: design review (/admin/reviews) for design reviewers and admins, journal
# review (/admin/journal-reviews) for reviewers and admins. Each is routed behind its own constraint and
# require_reviewer! checks again. Decisions are made as true_user, the person at the keyboard.
class Review::ApplicationController < ApplicationController
  before_action :require_reviewer!

  private

  def pundit_user = true_user
  def reviewer?(user) = user.reviews_designs?

  def require_reviewer!
    raise ActionController::RoutingError, "Not Found" unless true_user && reviewer?(true_user)
  end
end
