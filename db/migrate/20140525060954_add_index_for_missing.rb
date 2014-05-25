class AddIndexForMissing < ActiveRecord::Migration
  def change
    remove_index :reports, [:branch]
    add_index :reports, [:branch]
    remove_index :reports, [:datetime]
    add_index :reports, [:datetime]
    remove_index :servers, [:name]
    add_index :servers, [:name]
  end
end
