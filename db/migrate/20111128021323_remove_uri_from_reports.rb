class RemoveUriFromReports < ActiveRecord::Migration[4.2]
  def up
    remove_column :reports, :uri
  end

  def down
    add_column :reports, :uri, :string
  end
end
