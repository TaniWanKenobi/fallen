# frozen_string_literal: true

# == Schema Information
#
# Table name: reviewer_notes
#
#  id            :bigint           not null, primary key
#  body          :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  project_id    :bigint           not null
#  submission_id :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_reviewer_notes_on_project_id     (project_id)
#  index_reviewer_notes_on_submission_id  (submission_id)
#  index_reviewer_notes_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (submission_id => submissions.id)
#  fk_rails_...  (user_id => users.id)
#
class ReviewerNoteSerializer < ApplicationSerializer
  typelize_from ReviewerNote
  typelize id: :string, author: "{ id: string; name: string; avatar: string }"
  attributes :body, :created_at
  attribute(:id) { |note| note.public_id }
  one :user, key: :author, resource: PersonSerializer
end
