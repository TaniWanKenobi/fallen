# The second Tamagotchi workshop moved from Wednesday Nov 11 to Thursday Nov 12, same time; keep earlier sign-ups on it.
# One update on a small table, so nothing is locked for long.
class MoveWorkshopRsvpsToNov12 < ActiveRecord::Migration[8.1]
  def up
    safety_assured { execute "UPDATE workshop_rsvps SET slot = 'nov12' WHERE slot = 'nov11'" }
  end

  def down
    safety_assured { execute "UPDATE workshop_rsvps SET slot = 'nov11' WHERE slot = 'nov12'" }
  end
end
