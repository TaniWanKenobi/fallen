# Once a day, tells the reviewers' Slack channel when the journal review queue is backing up: projects waiting longer
# than NUDGE_AFTER. Beginners only learn from feedback that comes while they're still building.
class ProgressQueueNudgeJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  NUDGE_AFTER = 2.days

  def self.channel_id = ENV["SLACK_REVIEWERS_CHANNEL_ID"].presence

  def perform
    return unless self.class.channel_id && SlackBot.configured?

    queued = ProgressStatus.queued
    oldest = queued.minimum(:due_since)
    return if oldest.nil? || oldest > NUDGE_AFTER.ago

    SlackBot.client.chat_postMessage(channel: self.class.channel_id, unfurl_links: false,
      **SlackMessages.progress_queue_nudge(waiting: queued.count, late: queued.where(due_since: ...NUDGE_AFTER.ago).count,
        requested: queued.where(due_reason: "requested").count, oldest:))
  end
end
