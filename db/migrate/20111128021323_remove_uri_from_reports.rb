class RemoveUriFromReports < ActiveRecord::Migration
  def up
    remove_column :reports, :uri
  end

  def down
    add_column :reports, :uri, :string
  end
end
