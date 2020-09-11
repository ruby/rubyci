class Server < ApplicationRecord
  validates :name, :length => { :in => 3..30 }
  validates :uri, :length => { :in => 20..200 }
  validates :ordinal, :numericality => true, :uniqueness => true

  def recent_uri(branch)
    "#{uri.chomp('/')}/ruby-#{branch}/recent.html"
  end
end
