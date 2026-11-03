class RepoSnapshotJob < ApplicationJob
  queue_as :background
  # Two at a time across everyone: each holds a worker thread for up to GitRemote::TIMEOUT a step, and the
  # background pool is shared.
  limits_concurrency to: 2, key: "repo_snapshot", duration: 3.minutes

  def perform(snapshot)
    snapshot.fetch! if snapshot.pending?
  end
end
