class CreateRecents < ActiveRecord::Migration[6.1]
  def change
    create_table :recents do |t|
      t.string :name, null: false
      t.references :server, null: false, foreign_key: true
      t.string :etag, null: false

      t.timestamps
    end
  end
end
