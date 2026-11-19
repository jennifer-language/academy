require 'resque'
Resque.redis = Redis.new(host: '127.0.0.1', port: 16380)
class SendWelcome
  @queue = :mail
  def self.perform(email, lang)
    puts "ruby worker: welcome #{email} (#{lang})"
  end
end
if ARGV[0] == 'enqueue'
  Resque.enqueue_to(:mail, 'SendWelcome', 'carol@example.org', 'fr')
  Resque.enqueue_to(:mail, 'SendWelcome', 'dave@example.org', 7)
else
  w = Resque::Worker.new(:mail)
  w.work(0)
end
