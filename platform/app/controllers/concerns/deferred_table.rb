# frozen_string_literal: true

module DeferredTable
  extend ActiveSupport::Concern

  private

  # A paginated table as deferred props: `key` (rows) and `pagy`, fetched together after the page shell renders.
  # The block can return extra serializer params for the loaded page of records.
  def deferred_table(scope, serializer, key, &serializer_params)
    page = -> { @deferred_page ||= pagy(scope).then { |pagy, records| [ pagy, records.to_a ] } }

    {
      key => InertiaRails.defer(group: "table") do
        records = page.call.last
        serializer.render(records, **(serializer_params&.call(records) || {}))
      end,
      pagy: InertiaRails.defer(group: "table") { pagy_props(page.call.first) }
    }
  end
end
