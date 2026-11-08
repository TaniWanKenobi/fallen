class AddDailyGoalMinutesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :daily_goal_minutes, :integer
  end
end
