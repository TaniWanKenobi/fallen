# A repository as it was when someone checked it from the submit popup (GitRemote does the reading, in
# RepoSnapshotJob). A Submission keeps the one it was made from, so reviewers read what was submitted even after
# the repo changes or goes away.
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
class RepoSnapshot < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :rps
  has_paper_trail skip: %i[tree readme bom_csv]

  STATUSES = %w[pending done failed].freeze
  # A submission has to use a check this recent, so what's reviewed is what's in the repo.
  FRESH_FOR = 2.hours
  # Checks one person can start in an hour, so the popup can't be used to make us hammer someone's server.
  PER_HOUR = 30

  belongs_to :project
  belongs_to :user
  has_many :repo_files, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :url, presence: true

  after_create_commit -> { RepoSnapshotJob.perform_later(self) }

  def self.start(project:, user:, url:)
    url = GitRemote.normalize(url)
    return :throttled if where(user:).where(created_at: 1.hour.ago..).count >= PER_HOUR

    create!(project:, user:, url:)
  end

  def pending? = status == "pending"
  def done? = status == "done"
  def failed? = status == "failed"
  def fresh? = done? && fetched_at && fetched_at > FRESH_FOR.ago

  def fetch!
    data = GitRemote.snapshot(url)
    update!(status: "done", fetched_at: Time.current, error: nil, **data.to_h.except(:url))
  rescue GitRemote::Error => e
    update!(status: "failed", fetched_at: Time.current, error: e.message)
  end

  def paths = tree.filter_map { |entry| entry["path"] if entry["type"] == "blob" }
  def file_url(path) = GitRemote.file_url(url, commit_sha, path)
end
