class Logfile < ActiveRecord::Base
  belongs_to :report
  validates :report_id, :presence => true
  validates :ext,
    :uniqueness => { :scope => :report_id },
    :inclusion => { :in => %w[log.txt diff.txt log.html diff.html],
      :message => "%{value} is not a valid ext" }
  validates :data, :presence => true

  def uri
    r = report
    t = r.datetime.strftime('%Y%m%dT%H%M%SZ')
    "#{r.server.uri}ruby-#{r.branch}/log/#{t}.#{ext}.gz"
  end
end
