class Server < ApplicationRecord
  validates :name, :length => { :in => 3..30 }
  validates :uri, :length => { :in => 20..200 }
  validates :ordinal, :numericality => true, :uniqueness => true

  RUBYCI_S3_HOST = 'rubyci.s3.amazonaws.com'
  RUBYCI_S3_URI = %r{\Ahttps?://#{Regexp.escape(RUBYCI_S3_HOST)}/}

  # Most rows still carry the http:// form these URIs were first registered
  # with, so both schemes have to match. Keep the Ruby and SQL forms together
  # or they drift apart and each caller covers a different set of servers.
  scope :rubyci_s3, -> {
    where("uri LIKE :http OR uri LIKE :https",
      http: "http://#{RUBYCI_S3_HOST}/%", https: "https://#{RUBYCI_S3_HOST}/%")
  }

  def rubyci_s3?
    RUBYCI_S3_URI.match?(uri.to_s)
  end

  def recent_uri(branch)
    "#{uri.chomp('/')}/ruby-#{branch}/recent.html"
  end
end
