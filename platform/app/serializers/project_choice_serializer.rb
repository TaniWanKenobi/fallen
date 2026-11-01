# frozen_string_literal: true

# A project to pick from a list, by name.
class ProjectChoiceSerializer < ApplicationSerializer
  typelize_from Project
  typelize id: :string
  attributes :title
  attribute(:id) { |project| project.public_id }
end
