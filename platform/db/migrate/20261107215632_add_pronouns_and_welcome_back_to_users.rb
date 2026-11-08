class AddPronounsAndWelcomeBackToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pronouns, :string
    add_column :users, :welcome_back_seen_at, :datetime
  end
end
