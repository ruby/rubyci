class AddOrdinalToServer < ActiveRecord::Migration[4.2]
  def change
    add_column :servers, :ordinal, :float
    Server.all.each_with_index do |x, i|
      x.update! :ordinal => i
    end
  end
end
