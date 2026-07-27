class ChangeReportsRevisionToString < ActiveRecord::Migration[8.1]
  def up
    if postgresql?
      change_column :reports, :revision, :string, using: 'revision::text'
      # varchar_pattern_ops is required for LIKE 'abc1234%' prefix searches
      add_index :reports, :revision, opclass: :varchar_pattern_ops
    else
      change_column :reports, :revision, :string
      add_index :reports, :revision
    end
  end

  def down
    remove_index :reports, :revision
    if postgresql?
      change_column :reports, :revision, :integer, using: 'revision::integer'
    else
      change_column :reports, :revision, :integer
    end
  end

  private

  def postgresql?
    connection.adapter_name.match?(/postgresql/i)
  end
end
