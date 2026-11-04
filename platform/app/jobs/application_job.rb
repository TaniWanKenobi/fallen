class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError

  # Changes a job makes are attributed to whoever enqueued it (nil for scheduled jobs) and tagged with the job.
  around_perform do |job, block|
    PaperTrail.request(whodunnit: job.paper_trail_whodunnit, controller_info: { source: "job:#{job.class.name}" }, &block)
  end

  attr_reader :paper_trail_whodunnit

  # Jobs asked for inside the block go onto the queue together when it ends: one insert for all of them, where each
  # perform_later costs three queries. One asked for inside a transaction joins once it commits and is dropped if it
  # rolls back, as perform_later's would be; one whose transaction outlives the block is enqueued on its own.
  def self.batch
    return yield if ActiveSupport::IsolatedExecutionState[:job_batch]

    jobs = ActiveSupport::IsolatedExecutionState[:job_batch] = []
    yield
  ensure
    if jobs
      ActiveSupport::IsolatedExecutionState[:job_batch] = nil
      jobs.freeze
      ActiveJob.perform_all_later(*jobs) if jobs.any?
    end
  end

  def enqueue(options = {})
    jobs = ActiveSupport::IsolatedExecutionState[:job_batch]
    return super unless jobs

    set(options)
    ActiveRecord.after_all_transactions_commit { jobs.frozen? ? super() : jobs << self }
    self
  end

  def serialize = super.merge("paper_trail_whodunnit" => PaperTrail.request.whodunnit)

  def deserialize(job_data)
    super
    @paper_trail_whodunnit = job_data["paper_trail_whodunnit"]
  end
end
