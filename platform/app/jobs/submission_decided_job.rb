# Tells a project's team their design review is in: a DM each with the feedback, and a line in the project's
# thread when it was approved or sent back. One job per message (`to:` a person, or :thread), so a rerun after a
# restart repeats at most one.
class SubmissionDecidedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(submission, to: nil)
    return unless submission.decided? && SlackBot.configured?
    return fan_out(submission) if to.nil?

    if to == :thread || to == "thread"
      project = submission.project
      return if project.discarded? || !project.slack_linked? || submission.rejected?

      SlackBot.client.chat_postMessage(channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, **SlackMessages.submission_decided_in_thread(submission))
    elsif to.slack_id.present? && !to.discarded? && !to.is_banned?
      SlackBot.client.chat_postMessage(channel: to.slack_id, **SlackMessages.submission_decided(submission))
    end
  end

  private

  def fan_out(submission)
    [ submission.user, *submission.project.teammates ].uniq.each { |person| self.class.perform_later(submission, to: person) }
    self.class.perform_later(submission, to: "thread")
  end
end
