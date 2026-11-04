# Rewrites a journal review's reply in its project's thread after the reviewer edits the feedback (ProgressReview).
# The DMs only link to that reply, so they stay as they are.
class ProgressReviewEditedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  # A reply someone deleted, or a thread that's gone: nothing left to rewrite.
  GONE = %w[message_not_found channel_not_found cant_update_message].freeze

  def perform(review)
    project = review.project
    return unless review.slack_ts && SlackBot.configured? && project.slack_linked? && !project.discarded?

    SlackBot.client.chat_update(channel: project.slack_channel_id, ts: review.slack_ts, **SlackMessages.progress_reviewed(review))
  rescue Slack::Web::Api::Errors::SlackError => e
    raise unless GONE.include?(e.message)
  end
end
