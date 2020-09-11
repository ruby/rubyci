class DropOsAndArch < ActiveRecord::Migration[6.0]
  def change
    remove_column :servers, :arch, :string
    remove_column :servers, :os, :string
    remove_column :servers, :version, :string
  end
end
