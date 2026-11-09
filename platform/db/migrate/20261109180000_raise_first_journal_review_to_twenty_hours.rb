# The first journal review moves from 10h to 20h logged (ProgressStatus::FIRST_AT_MINUTES). Projects never reviewed
# take the new threshold, and ones queued for a first review under 20h leave the queue until they reach it; requested
# and admin-added ones stay. Two updates on a small table, so nothing is locked for long.
class RaiseFirstJournalReviewToTwentyHours < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute "UPDATE progress_statuses SET next_at_minutes = 1200 WHERE reviews_count = 0 AND next_at_minutes = 600"
      execute <<~SQL
        UPDATE progress_statuses SET due_reason = NULL, due_since = NULL
        WHERE reviews_count = 0 AND due_reason = 'first' AND logged_minutes < 1200
      SQL
    end
  end

  # The projects taken out of the queue come back the next time their journals change (ProgressStatus.refresh).
  def down
    safety_assured { execute "UPDATE progress_statuses SET next_at_minutes = 600 WHERE reviews_count = 0 AND next_at_minutes = 1200" }
  end
end
