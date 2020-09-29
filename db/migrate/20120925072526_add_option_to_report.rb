class AddOptionToReport < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :option, :string
  end
end
