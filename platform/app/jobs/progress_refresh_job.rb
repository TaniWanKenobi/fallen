# Works out whether a project is due for journal review (ProgressStatus.refresh) after its journals' hours change or
# it's submitted. A job so saving a journal never waits on it.
class ProgressRefreshJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find_by(id: project_id) or return
    ProgressStatus.refresh(project)
  end
end
