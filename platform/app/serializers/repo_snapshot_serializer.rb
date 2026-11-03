# frozen_string_literal: true

# The submit popup's view of a repository check: enough to say what was found.
# == Schema Information
#
# Table name: repo_snapshots
#
#  id             :bigint           not null, primary key
#  bom_csv        :text
#  bom_path       :string
#  branch         :string
#  commit_sha     :string
#  error          :text
#  fetched_at     :datetime
#  host           :string
#  readme         :text
#  readme_path    :string
#  status         :string           default("pending"), not null
#  tree           :jsonb            not null
#  tree_truncated :boolean          default(FALSE), not null
#  url            :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  project_id     :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_repo_snapshots_on_project_id  (project_id)
#  index_repo_snapshots_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class RepoSnapshotSerializer < ApplicationSerializer
  typelize_from RepoSnapshot
  typelize id: :string, status: "'pending' | 'done' | 'failed'", file_count: :number, bom_csv: [ :string, nullable: true ]
  attributes :url, :status, :error, :host, :branch, :commit_sha, :readme_path, :bom_path, :tree_truncated
  attribute(:id) { |snapshot| snapshot.public_id }
  attribute(:file_count) { |snapshot| snapshot.paths.size }
  attribute(:bom_csv) { |snapshot| snapshot.done? ? snapshot.bom_csv : nil }
end
