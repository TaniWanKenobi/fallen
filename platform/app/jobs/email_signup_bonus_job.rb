# Tells someone in a Slack DM that they earned the email signup bonus (XpEntry.grant_email_signup), when it's paid or,
# for someone without Slack then, when they link it (User#send_email_signup_dm).
class EmailSignupBonusJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(entry)
    return if entry.discarded? || entry.user.slack_id.blank? || !SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: entry.user.slack_id, **SlackMessages.email_signup_bonus(entry.amount))
  end
end
