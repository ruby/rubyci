class CreateLogfiles < ActiveRecord::Migration[4.2]
  def change
    create_table :logfiles do |t|
      t.integer :report_id
      t.string :ext
      t.binary :data

      t.timestamps
    end
    add_index :logfiles, :report_id
    add_index :logfiles, [:report_id, :ext], unique: true
  end
end
