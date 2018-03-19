# Modified from https://github.com/resque/resque-loner/blob/master/tasks/redis.rake
require 'fileutils'
require 'open-uri'
require 'pathname'

class RedisRunner
  include FileUtils
  def self.redis_dir
    @redis_dir ||= if ENV['PREFIX']
                     Pathname.new(ENV['PREFIX'])
                   else
                     Pathname.new(`which redis-server`) + '..' + '..'
                   end
  end

  def self.bin_dir
    redis_dir + 'bin'
  end
  def self.config=(val)
    @config=val
  end

  def self.config
    @config ||= if File.exists?(redis_dir + 'etc/redis.conf')
                  redis_dir + 'etc/redis.conf'
                else
                  redis_dir + '../etc/redis.conf'
                end
  end

  def self.dtach_socket
    '/tmp/redis.dtach'
  end

  # Just check for existance of dtach socket
  def self.running?
    File.exists? dtach_socket
  end

  def self.start
    puts 'Detach with Ctrl+\  Re-attach with rake redis:attach'
    sleep 1
    command = "#{bin_dir}/redis-server #{config}"
    spawn command
  end

  def self.attach
    exec "#{bin_dir}/dtach -a #{dtach_socket}"
  end

  def self.stop
    spawn 'echo "SHUTDOWN" | nc localhost 6379'
  end


end

namespace :redis do
  desc 'Start redis'
  task :start do
    RedisRunner.config = "./config/redis.conf"
    RedisRunner.start
  end

  desc 'Stop redis'
  task :stop do
    RedisRunner.stop
  end

  desc 'Restart redis'
  task :restart do
    RedisRunner.stop
    RedisRunner.start
  end

  desc 'Attach to redis dtach socket'
  task :attach do
    RedisRunner.attach
  end
end
