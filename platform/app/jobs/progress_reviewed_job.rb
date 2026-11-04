# Tells a project's team a reviewer has read their journals (ProgressReview): the feedback goes in the project's
# thread first, then each person on the team is DMed a link to it. One job per message (`to:` a person), so a rerun
# after a restart repeats at most one; the thread reply is posted once, whatever reruns.
class ProgressReviewedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(review, to: nil)
    project = review.project
    return unless review.sent? && SlackBot.configured? && !project.discarded?
    return reply_then_dm(review) if to.nil?
    return reply(review) if to == "thread" # Queued by the version before DMs linked to the reply.
    return if to.slack_id.blank? || to.discarded? || to.is_banned?

    SlackBot.client.chat_postMessage(channel: to.slack_id, **SlackMessages.progress_reviewed_dm(review))
  end

  private

  def reply_then_dm(review)
    reply(review)
    review.project.teammates.uniq.each { |person| self.class.perform_later(review, to: person) }
  end

  def reply(review)
    project = review.project
    return unless project.slack_linked? && review.slack_ts.nil?

    posted = SlackBot.client.chat_postMessage(channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, **SlackMessages.progress_reviewed(review))
    review.update_column(:slack_ts, posted["ts"])
  end
end
