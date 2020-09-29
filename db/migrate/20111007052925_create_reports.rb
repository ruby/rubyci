class CreateReports < ActiveRecord::Migration[4.2]
  def change
    create_table :reports do |t|
      t.integer :server_id
      t.datetime :datetime
      t.string :branch
      t.integer :revision
      t.string :uri
      t.string :summary

      t.timestamps
    end
  end
end
