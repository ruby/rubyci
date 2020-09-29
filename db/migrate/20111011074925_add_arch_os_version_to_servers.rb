class AddArchOsVersionToServers < ActiveRecord::Migration[4.2]
  def change
    add_column :servers, :arch, :string
    add_column :servers, :os, :string
    add_column :servers, :version, :string
  end
end
