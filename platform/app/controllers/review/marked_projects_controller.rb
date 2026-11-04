# The projects journal reviewers marked: starred as standouts (/admin/starred) or flagged as written by AI
# (/admin/ai-flags), newest first. The route sets `kind`.
class Review::MarkedProjectsController < Review::ApplicationController
  include DeferredTable

  KINDS = %w[starred flagged].freeze

  def index
    kind = params[:kind].presence_in(KINDS) or raise ActionController::RoutingError, "Not Found"
    scope = policy_scope([ :review, ProgressStatus ])
    statuses = kind == "starred" ? scope.starred.order(starred_at: :desc, id: :desc) : scope.flagged.order(flagged_at: :desc, id: :desc)

    render inertia: "Review/MarkedProjects/Index", props: {
      kind:,
      **deferred_table(statuses.includes(:flagged_by, :starred_by, project: :user), ProgressRowSerializer, :projects)
    }
  end

  private

  def reviewer?(user) = user.reviews_journals?
end
