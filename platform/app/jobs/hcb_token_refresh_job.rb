class HcbTokenRefreshJob < ApplicationJob
  queue_as :background

  def perform
    connection = HcbConnection.current
    connection.refresh! if Hcb.configured? && connection&.expiring_soon?
  end
end
