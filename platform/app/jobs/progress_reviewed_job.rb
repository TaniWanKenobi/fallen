# Tells a project's team a reviewer has read their journals (ProgressReview): a DM each with the feedback, and a reply
# in the project's thread. One job per message (`to:` a person, or
# :thread), so a rerun after a restart repeats at most one.
class ProgressReviewedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(review, to: nil)
    project = review.project
    return unless review.sent? && SlackBot.configured? && !project.discarded?
    return fan_out(review) if to.nil?

    if to == :thread || to == "thread"
      return unless project.slack_linked?

      SlackBot.client.chat_postMessage(channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, **SlackMessages.progress_reviewed(review))
    elsif to.slack_id.present? && !to.discarded? && !to.is_banned?
      SlackBot.client.chat_postMessage(channel: to.slack_id, **SlackMessages.progress_reviewed_dm(review))
    end
  end

  private

  def fan_out(review)
    review.project.teammates.uniq.each { |person| self.class.perform_later(review, to: person) }
    self.class.perform_later(review, to: "thread")
  end
end
