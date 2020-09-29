class ChangeSummaryFromReports < ActiveRecord::Migration[4.2]
  def up
    change_column :reports, :summary, :text, limit: nil
  end

  def down
    change_column :reports, :summary, :string
  end
end
