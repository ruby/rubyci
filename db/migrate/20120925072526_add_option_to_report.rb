class AddOptionToReport < ActiveRecord::Migration
  def change
    add_column :reports, :option, :string
  end
end
