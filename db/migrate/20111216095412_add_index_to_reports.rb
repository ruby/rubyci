class AddIndexToReports < ActiveRecord::Migration
  def change
    add_index :reports, :server_id, :branch
  end
end
