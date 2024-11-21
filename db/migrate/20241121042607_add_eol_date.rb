class AddEolDate < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :eol_date, :date
  end
end
