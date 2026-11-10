class AddBomImportToRepoSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :repo_snapshots, :bom_import, :jsonb
  end
end
