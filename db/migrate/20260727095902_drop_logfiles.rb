class DropLogfiles < ActiveRecord::Migration[8.1]
  def change
    drop_table :logfiles do |t|
      t.datetime :created_at, precision: nil
      t.binary :data
      t.string :ext
      t.integer :report_id
      t.datetime :updated_at, precision: nil
      t.index [:report_id, :ext], name: "index_logfiles_on_report_id_and_ext", unique: true
      t.index [:report_id], name: "index_logfiles_on_report_id"
    end
  end
end
