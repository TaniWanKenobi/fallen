require "csv"

# Workshop sign-ups (WorkshopRsvp), kept apart from the program's stats: how many picked each time, who, and a CSV of
# a slot's emails for sending the call link on the day.
class Admin::WorkshopRsvpsController < Admin::ApplicationController
  def index
    authorize [ :admin, WorkshopRsvp ]
    rsvps = policy_scope([ :admin, WorkshopRsvp ])

    render inertia: "Admin/WorkshopRsvps/Index", props: {
      title: WorkshopRsvp::TITLE, slots: WorkshopRsvp.slots, slot:,
      counts: InertiaRails.defer(group: "table") { rsvps.group(:slot).count },
      **deferred_table(rows(rsvps), AdminWorkshopRsvpSerializer, :rsvps)
    }
  end

  def export
    authorize [ :admin, WorkshopRsvp ], :index?
    send_data csv(rows(policy_scope([ :admin, WorkshopRsvp ]))), filename: "workshop-rsvps#{"-#{slot}" if slot}.csv", type: "text/csv"
  end

  private

  def slot = WorkshopRsvp::SLOTS.key?(params[:slot]) ? params[:slot] : nil

  def rows(rsvps) = (slot ? rsvps.where(slot:) : rsvps).order(created_at: :desc)

  def csv(rows)
    CSV.generate do |out|
      out << %w[email slack_username slot signed_up_at]
      rows.unscope(:order).find_each(order: :desc) { |rsvp| out << [ rsvp.email, rsvp.slack_username, rsvp.slot, rsvp.created_at.iso8601 ].map { cell(it) } }
    end
  end

  # Sign-ups are typed by anyone, so a cell a spreadsheet would read as a formula is kept as text.
  def cell(value) = value.to_s.start_with?("=", "+", "-", "@", "\t", "\r") ? "'#{value}" : value
end
