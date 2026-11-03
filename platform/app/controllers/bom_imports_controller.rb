# The submit popup's BOM step: turns a bom.csv into rows for the person to check (BomImport). Nothing is saved.
# JSON only.
class BomImportsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  rate_limit to: 30, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    authorize BomImport
    result = BomImport.parse(params.expect(:csv))
    render json: { items: result.items.map(&:to_h), warnings: result.warnings, mapping: result.mapping }
  end
end
