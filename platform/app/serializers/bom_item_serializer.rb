# frozen_string_literal: true

# A line of a submitted bill of materials, with the reviewer's call on it once the review is in.
# == Schema Information
#
# Table name: bom_items
#
#  id             :bigint           not null, primary key
#  approved_cents :integer
#  kind           :string           default("part"), not null
#  link           :string
#  name           :string           not null
#  owned          :boolean          default(FALSE), not null
#  position       :integer          not null
#  purpose        :string
#  quantity       :integer          default(1), not null
#  reason         :string
#  total_cents    :integer          not null
#  unit_cents     :integer
#  vendor         :string
#  verdict        :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  submission_id  :bigint           not null
#
# Indexes
#
#  index_bom_items_on_submission_id  (submission_id)
#
# Foreign Keys
#
#  fk_rails_...  (submission_id => submissions.id)
#
class BomItemSerializer < ApplicationSerializer
  typelize_from BomItem
  typelize id: :string, kind: "'part' | 'shipping' | 'tax'", verdict: "'approved' | 'adjusted' | 'cut' | null", funded_cents: [ :number, nullable: true ]
  attributes :kind, :name, :purpose, :quantity, :unit_cents, :total_cents, :link, :vendor, :owned, :verdict, :reason, :approved_cents
  attribute(:id) { |item| item.public_id }
  attribute(:funded_cents) { |item| item.verdict && item.funded_cents }
end
