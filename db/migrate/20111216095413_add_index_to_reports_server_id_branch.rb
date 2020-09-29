class AddIndexToReportsServerIdBranch < ActiveRecord::Migration[4.2]
  def change
    add_index :reports, [:server_id, :branch]
  end
end
