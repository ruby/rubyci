class AddIndexToReportsServerIdBranchOption < ActiveRecord::Migration[7.0]
  def change
    add_index :reports, [:server_id, :branch, :option]
    remove_index :reports, [:server_id, :branch]
  end
end
