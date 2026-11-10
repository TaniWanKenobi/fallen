# Reads a repository check's bom.csv into parts rows (BomExtraction), so the submit popup's parts list fills itself.
class BomExtractionJob < ApplicationJob
  queue_as :default
  # A model writing out a long parts list holds a worker thread for a minute or more.
  limits_concurrency to: 3, key: "bom_extraction", duration: 5.minutes

  def perform(snapshot)
    snapshot.read_bom! if snapshot.bom_state == "pending"
  end
end
