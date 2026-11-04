class JournalsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  # Every move posts the journal into another thread afresh.
  rate_limit to: 10, within: 10.minutes, only: :move, by: -> { current_user.id }, with: -> { redirect_back_or_to projects_path, alert: "Too many moves, try again in a few minutes." }
  before_action :set_project, only: :create
  before_action :set_journal, only: %i[update destroy move]
  # Saving a journal sets off its Slack mirror, a journal review refresh and maybe a bonus DM.
  around_action :batch_jobs, only: %i[create update destroy move]

  def create
    journal = @project.journals.build(journal_params.merge(user: current_user, source: "web"))
    authorize journal

    if journal.save
      SyncJournalToSlackJob.perform_later(journal, "create")
      settle_writing_check(journal)
      redirect_to project_path(@project), notice: "Journal logged."
    else
      inertia_errors(journal, fallback_location: project_path(@project))
    end
  end

  def update
    authorize @journal

    if @journal.update(journal_params.merge(edited_on_site: true))
      SyncJournalToSlackJob.perform_later(@journal, "update")
      settle_writing_check(@journal) if @journal.saved_change_to_body?
      redirect_to project_path(@journal.project), notice: "Journal updated."
    else
      inertia_errors(@journal, fallback_location: project_path(@journal.project))
    end
  end

  def destroy
    authorize @journal
    @journal.discard
    SyncJournalToSlackJob.perform_later(@journal, "delete")
    redirect_to project_path(@journal.project), notice: "Journal deleted."
  end

  def move
    authorize @journal
    from = @journal.project
    slack = @journal.slack_location
    target = Project.kept.teamed_with(current_user).find_by_public_id!(params.expect(:project_id))

    if @journal.move_to(target)
      SyncJournalToSlackJob.perform_later(@journal, "move", slack)
      redirect_to project_path(from), notice: "Journal moved to #{target.title}."
    else
      redirect_to project_path(from), alert: @journal.errors.full_messages.to_sentence
    end
  end

  private

  def batch_jobs(&) = ApplicationJob.batch(&)

  def set_project
    @project = Project.kept.find_by_public_id!(params[:project_id])
  end

  def set_journal
    @journal = Journal.kept.find_by_public_id!(params[:id])
  end

  # `images` is the full list of blob signed ids (direct uploads) the journal should end up with, and
  # `lapse_timelapses` the full list of the person's timelapse public ids, left out to keep the ones it has.
  def journal_params
    permitted = params.expect(journal: [ :body, :duration, images: [], lapse_timelapses: [] ])
    permitted.to_h.symbolize_keys.tap do |h|
      h[:images] = Array(h[:images]).compact_blank
      h[:picked_timelapses] = picked_timelapses(Array(h.delete(:lapse_timelapses)).compact_blank.uniq) if h.key?(:lapse_timelapses)
    end
  end

  # The composer sends the WritingCheck it ran, and `insisted` when the person held "I wrote this myself".
  def settle_writing_check(journal)
    WritingCheck.settle(journal, params[:writing_check], insisted: params[:insisted].to_s == "true") if WritingCheck.enabled_for?(current_user)
  end

  def picked_timelapses(ids)
    timelapses = current_user.lapse_timelapses.where_public_ids(ids.first(Journal::MAX_TIMELAPSES + 1)).to_a
    raise ActiveRecord::RecordNotFound, "Unknown timelapse" if timelapses.size < [ ids.size, Journal::MAX_TIMELAPSES + 1 ].min

    timelapses
  end
end
