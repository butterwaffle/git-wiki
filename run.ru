#!/usr/bin/env rackup

env ||= ENV['RACK_ENV'] || 'development'

path = ::File.expand_path(::File.dirname(__FILE__))

$LOAD_PATH << ::File.join(path, 'lib')
Dir[::File.join(path, 'deps', '*', 'lib')].each {|x| $: << x }

require 'rubygems'
require 'fileutils'
require 'logger'
require 'rack/patched_request'
require 'rack/path_info'
require 'rack/esi'
require 'rack/session/pstore'
require 'rack/reverseip'
require 'rack/ban_ip'
require 'rack/anti_spam'
require 'wiki/app'

repo_path = nil
config_file = if ENV['WIKI_CONFIG']
  ENV['WIKI_CONFIG']
else
  if ::File::exist?( ::File.join( path, 'config.yml' ) )
    ::File.join(path, 'config.yml')
  else
    epath = ::File.expand_path( Dir.pwd )
    repo = nil
    until repo or epath == '/'
      begin
        repo = Git.open( epath )
      rescue
        epath = ::File.expand_path( ::File.join( epath, '..' ) )
      end
    end
    if repo
      if ::File::exist?( ::File.join( repo.dir.path, '.wiki.config.yml' ) )
        repo_path = repo.dir.path
        ::File.join( repo.dir.path, '.wiki.config.yml' )
      end
    end
  end
end

default_config = {
  :title        => 'Git-Wiki',
  :root         => path,
  :production   => false,
  :locale	=> 'en_US',
  :auth => {
    :service => 'yamlfile',
    :store   => ::File.join(path, '.wiki', 'users.yml'),
  },
  :cache        => ::File.join(path, '.wiki', 'cache'),
  :mime => {
    :default => 'text/x-creole',
    :magic   => true,
  },
  :main_page    => 'Home',
  :disabled_plugins => ['misc/private_wiki', 'tagging', 'filter/orgmode'],
  :rack => {
    :rewrite_base => nil,
    :profiling    => false,
    :tidy         => nil,
    :anti_spam    => false,
  },
  :git => {
    :repository => ::File.join(path, '.wiki', 'repository'),
    :workspace  => ::File.join(path, '.wiki', 'workspace'),
  },
  :log => {
    :level => 'INFO',
    :file  => ::File.join(path, '.wiki', 'log'),
  },
}

Wiki::Config.update(default_config)
Wiki::Config.load(config_file)
if repo_path
  Wiki::Config.auth.store = Wiki::Config.auth.store.gsub( "@REPOSITORY_PATH@", repo_path )
  Wiki::Config.cache = Wiki::Config.cache.gsub( "@REPOSITORY_PATH@", repo_path )
  Wiki::Config.log.file = Wiki::Config.log.file.gsub( "@REPOSITORY_PATH@", repo_path )
  Wiki::Config.git.repository = Wiki::Config.git.repository.gsub( "@REPOSITORY_PATH@", repo_path )
  Wiki::Config.git.wikitop = Wiki::Config.git.wikitop.gsub( "@REPOSITORY_PATH@", repo_path )
  Wiki::Config.git.workspace = Wiki::Config.git.workspace.gsub( "@REPOSITORY_PATH@", repo_path )
end

if Wiki::Config.rack.profiling?
  require 'rack/contrib'
  use Rack::Profiler, :printer => :graph
end

if Wiki::Config.rack.anti_spam?
  use Rack::BanIP, :file => ::File.join(Wiki::Config.root, 'banned.list')
  use Rack::AntiSpam
end

use Rack::Session::PStore, :file => ::File.join(Wiki::Config.cache, 'session.pstore')
use Rack::ReverseIP
use Rack::PathInfo
use Rack::MethodOverride

if !Wiki::Config.rack.tidy.blank?
  begin
    require 'rack/contrib'
    use Rack::Tidy, :mode => Wiki::Config.rack.tidy.to_sym
  rescue
  end
end

if !Wiki::Config.rack.rewrite_base.blank?
  require 'rack/rewrite'
  use Rack::Rewrite, :base => Wiki::Config.rack.rewrite_base
end

FileUtils.mkdir_p ::File.dirname(Wiki::Config.log.file), :mode => 0755
logger = Logger.new(Wiki::Config.log.file)
logger.level = Logger.const_get(Wiki::Config.log.level)

use Rack::ESI, :no_cache => true
use Rack::CommonLogger, logger

if env == 'deployment' || env == 'production'
  require 'rack/cache'
  require 'rack/purge'
  use Rack::Purge
  use Rack::Cache,
    :verbose     => false,
    :metastore   => "file:#{::File.join(Wiki::Config.cache, 'rack', 'meta')}",
    :entitystore => "file:#{::File.join(Wiki::Config.cache, 'rack', 'entity')}"
  Wiki::Config.production = true
end

use Rack::Static, :urls => ['/static'], :root => path
run Wiki::App.new(nil, :logger => logger)
