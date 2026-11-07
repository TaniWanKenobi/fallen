# Pays Team Lulu's weekly bonus to everyone whose week, counted from their first journal, has just ended
# (config/recurring.yml, hourly).
class SettleLuluWeeksJob < ApplicationJob
  queue_as :background

  def perform
    Team.settle
  end
end
