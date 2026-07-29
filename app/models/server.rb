class Server < ApplicationRecord
  validates :name, :length => { :in => 3..30 }
  validates :uri, :length => { :in => 20..200 }
  validates :ordinal, :numericality => true, :uniqueness => true

  RUBYCI_S3_HOST = 'rubyci.s3.amazonaws.com'
  RUBYCI_S3_URI = %r{\Ahttps?://#{Regexp.escape(RUBYCI_S3_HOST)}/}
  # Fastly in front of the same bucket. Object keys are unchanged, so only the
  # host is swapped.
  RUBYCI_LOGS_URL = 'https://logs.rubyci.org'

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

  # Base for the log links shown to users. Bucket-backed servers go through the
  # CDN; every other server keeps the URI it was registered with.
  def log_base_uri
    uri.sub(RUBYCI_S3_URI, "#{RUBYCI_LOGS_URL}/").chomp('/')
  end

  def recent_uri(branch)
    "#{log_base_uri}/ruby-#{branch}/recent.html"
  end
end
