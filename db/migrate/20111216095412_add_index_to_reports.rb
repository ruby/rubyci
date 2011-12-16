class AddIndexToReports < ActiveRecord::Migration
  def change
    add_index :reports, :branch
    add_index :reports, :datetime
    add_index :servers, :name
  end
end
