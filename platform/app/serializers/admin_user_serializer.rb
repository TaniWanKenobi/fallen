# frozen_string_literal: true

# Admin-only. Rows in /admin/users.
class AdminUserSerializer < UserSerializer
  typelize discarded_at: [ :string, nullable: true ], is_trial: :boolean, soft_signup: [ :string, nullable: true ], pronouns: [ :string, nullable: true ]
  attributes :pronouns, :slack_id, :last_seen_at, :created_at, :discarded_at, :soft_signup
  attribute(:is_trial, &:trial?)
end
