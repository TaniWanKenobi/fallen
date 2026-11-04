# Posts a project a journal reviewer flagged for AI to the private #fallen-ai-flags channel, beside Pangram's flags
# (ReportWritingFlagJob), so staff see both kinds in one place. Clearing it is done on its review page.
class ReportProgressFlagJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(status)
    channel = ReportWritingFlagJob.channel_id
    return unless channel && SlackBot.configured? && status.flagged?

    SlackBot.client.chat_postMessage(channel:, unfurl_links: false, **SlackMessages.progress_flagged(status))
  end
end
