class CreateLogExcerpts < ActiveRecord::Migration[8.1]
  def change
    create_table :log_excerpts do |t|
      t.integer :report_id, null: false
      t.text :content, null: false
      t.timestamps
      t.index [:report_id], unique: true
    end
    add_foreign_key :log_excerpts, :reports

    # pg_trgm and GIN index are PostgreSQL-only; development and test run on SQLite
    if connection.adapter_name == "PostgreSQL"
      enable_extension "pg_trgm"
      add_index :log_excerpts, :content, using: :gin, opclass: :gin_trgm_ops,
        name: "index_log_excerpts_on_content_trgm"
    end
  end
end
