class Server < ActiveRecord::Base
  validates :name, :length => { :in => 3..30 }
  validates :arch, :inclusion => { :in => %w(x86 x64),
        :message => "%{value} is not a valid arch" }
  validates :os, :length => { :in => 3..20 }
  validates :version, :length => { :in => 3..20 }
  validates :uri, :length => { :in => 20..200 }
end
