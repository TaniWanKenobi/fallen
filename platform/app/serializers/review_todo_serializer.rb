# frozen_string_literal: true

# Something a journal review asked the team to fix, as the team and reviewers see it.
# == Schema Information
#
# Table name: review_todos
#
#  id                 :bigint           not null, primary key
#  body               :text             not null
#  done_at            :datetime
#  position           :integer          default(0), not null
#  resolved_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  done_by_id         :bigint
#  progress_review_id :bigint           not null
#  project_id         :bigint           not null
#
# Indexes
#
#  index_review_todos_on_done_by_id          (done_by_id)
#  index_review_todos_on_progress_review_id  (progress_review_id)
#  index_review_todos_on_project_id          (project_id)
#  index_review_todos_unresolved             (project_id) WHERE (resolved_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (done_by_id => users.id)
#  fk_rails_...  (progress_review_id => progress_reviews.id)
#  fk_rails_...  (project_id => projects.id)
#
class ReviewTodoSerializer < ApplicationSerializer
  typelize_from ReviewTodo
  typelize id: :string, done: :boolean, done_by: "{ id: string; name: string; avatar: string } | null"
  attributes :body, :done_at, :created_at
  attribute(:id) { |todo| todo.public_id }
  attribute(:done, &:done?)
  one :done_by, resource: PersonSerializer
end
