# Which of a journal draft's photos can't go on it any more, so the composer takes them out itself instead of the save
# being refused: a draft kept in the browser can hold a photo that has since gone out on another journal (a second
# tab posted it), and a photo goes on one journal only (Journal#images_are_new_uploads).
class PhotoChecksController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; create authorizes explicitly

  def create
    authorize current_user, :upload?
    ids = Array(params[:ids]).map(&:to_s).uniq.first(Journal::MAX_IMAGES * 2)
    blobs = ids.index_with { |id| ActiveStorage::Blob.find_signed(id) }
    taken = Journal.reused_uploads(blobs.values.compact, uploaders: [ current_user.id ], record: journal_being_edited || Journal.new).to_set

    render json: { taken: ids.select { |id| blobs[id].nil? || taken.include?(blobs[id]) } }
  end

  private

  # Photos already on the journal being edited stay usable on it.
  def journal_being_edited
    journal = Journal.kept.find_by_public_id(params[:journal].to_s) if params[:journal].present?
    journal if journal && policy(journal).update?
  end
end
