class AddLtsvToReport < ActiveRecord::Migration
  def change
    add_column :reports, :ltsv, :text
  end
end
