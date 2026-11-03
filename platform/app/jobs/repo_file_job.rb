class RepoFileJob < ApplicationJob
  queue_as :background
  # Shares RepoSnapshotJob's reasoning: each run holds a worker for up to a few GitRemote::TIMEOUTs.
  limits_concurrency to: 2, key: "repo_file", duration: 5.minutes

  def perform(snapshot)
    RepoFile.fetch_pending(snapshot)
  end
end
