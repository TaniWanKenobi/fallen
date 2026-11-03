# One file of a RepoSnapshot at its commit, fetched for the review page's file viewers. The snapshot only keeps the
# file list, README and BOM, so a reviewer opening another file asks for it here and RepoFileJob reads it through
# GitRemote; the page polls until it is done. The bytes are stored as an octet-stream attachment, so nothing in a
# repo is ever served as a page or script on our origin.
# == Schema Information
#
# Table name: repo_files
#
#  id               :bigint           not null, primary key
#  byte_size        :bigint
#  error            :text
#  fetched_at       :datetime
#  path             :string           not null
#  status           :string           default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  repo_snapshot_id :bigint           not null
#
# Indexes
#
#  index_repo_files_on_repo_snapshot_id_and_path  (repo_snapshot_id,path) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repo_snapshot_id => repo_snapshots.id) ON DELETE => cascade
#
class RepoFile < ApplicationRecord
  STATUSES = %w[pending done failed].freeze
  # A file that failed (the host was down, say) is tried again when asked for after this long.
  RETRY_AFTER = 10.minutes

  has_paper_trail
  belongs_to :repo_snapshot
  has_one_attached :content

  validates :status, inclusion: { in: STATUSES }
  validates :path, presence: true
  validate :path_in_snapshot, on: :create

  scope :pending, -> { where(status: "pending") }

  after_create_commit -> { RepoFileJob.perform_later(repo_snapshot) }

  # The file, made and queued the first time anyone asks for it. Returns nil for a path that isn't a file in the
  # snapshot.
  def self.request(snapshot, path)
    return nil unless snapshot.done? && snapshot.paths.include?(path)

    file = find_or_create_by!(repo_snapshot: snapshot, path:)
    file.retry! if file.failed? && file.updated_at < RETRY_AFTER.ago
    file
  rescue ActiveRecord::RecordNotUnique
    find_by!(repo_snapshot: snapshot, path:)
  end

  # Reads every pending file of the snapshot, GitRemote::MAX_FILES_PER_READ at a time.
  def self.fetch_pending(snapshot)
    files = snapshot.repo_files.pending.order(:id).limit(GitRemote::MAX_FILES_PER_READ).to_a
    return if files.empty?

    results = begin
      GitRemote.read_files(snapshot.url, snapshot.commit_sha, files.map(&:path))
    rescue GitRemote::Error => e
      files.index_by(&:path).transform_values { e }
    end
    files.each { |file| file.store(results[file.path] || GitRemote::Error.new("The file couldn't be read")) }
    RepoFileJob.perform_later(snapshot) if snapshot.repo_files.pending.exists?
  end

  def pending? = status == "pending"
  def done? = status == "done"
  def failed? = status == "failed"

  def store(result)
    if result.is_a?(String)
      content.attach(io: StringIO.new(result), filename: File.basename(path), content_type: "application/octet-stream", identify: false)
      update!(status: "done", byte_size: result.bytesize, error: nil, fetched_at: Time.current)
    else
      update!(status: "failed", error: result.message, fetched_at: Time.current)
    end
  end

  def retry!
    update!(status: "pending", error: nil)
    RepoFileJob.perform_later(repo_snapshot)
  end

  private

  def path_in_snapshot
    errors.add(:path, "isn't a file in this repository") unless repo_snapshot&.paths&.include?(path)
  end
end
