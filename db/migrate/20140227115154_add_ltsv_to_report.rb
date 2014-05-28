class AddLtsvToReport < ActiveRecord::Migration
  def change
    add_index :reports, [:branch]
    add_index :reports, [:datetime]
    add_index :servers, [:name]

    add_column :reports, :ltsv, :text
  end
end
