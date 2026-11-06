# Finds the Lapse and Lookout recordings for a transfer's Lapse review (TransferLapseReview#fetch_lapse!).
class FetchTransferLapseJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(transfer) { transfer }, duration: 5.minutes, on_conflict: :discard

  def perform(transfer)
    transfer.fetch_lapse! if transfer.lapse_fetching?
  end
end
