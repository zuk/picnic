require 'optparse'

require 'picnic'
require 'picnic/conf'
require 'picnic/server'

module Picnic
  # Provides a command-line interface for your app. 
  # This is useful for creating a 'bin' file for launching your application.
  #
  # Usage example (put this in a file called 'foo'):
  #
  #   #!/usr/bin/env ruby
  #
  #   require 'rubygems'
  #   require 'picnic'
  #
  #   require 'picnic/cli'
  #
  #   cli = Picnic::Cli.new(
  #     'foo',
  #     :app_path => "/path/to/foo.br"
  #   )
  #
  #   cli.handle_cli_input   
  #
  # Also see the ServiceControl class for info on how to use your cli script
  # as a service.
  class Cli
    attr_accessor :app, :options
    
    # Creates a new command-line interface handler.
    #
    # +app+:: The name of the application. This should match the name of the
    #         binary, which by default is expected to be in the same directory
    #         as the service control script.
    # +options+:: A hash overriding default options. The options are:
    #             +app_file+:: The path to your application's main Ruby file.
    #                          By default this is expected to be <tt>../lib/<app>.rb</tt>
    #             +pid_file+:: Where the app's PID file (containing the app's
    #                          process ID) should be placed. By default this is
    #                          <tt>/etc/<app>/<app>.pid</tt>
    def initialize(app, options = {})
      @app = app
      
      @options = options || {}
      @options[:app_file]   ||= File.expand_path(File.dirname(File.expand_path($0))+"/../lib/#{app}.rb")
      @options[:app_name]   ||= app
      @options[:app_module] ||= app.capitalize
      @options[:pid_file]   ||= "/etc/#{app}/#{app}.pid"
      @options[:conf_file]  ||= nil
    end
    
    # Parses command line options given to the script.
    def handle_cli_input
      if File.exists? options[:app_file]
        # try to use given app base path
        $APP_ROOT = File.dirname(options[:app_file]).gsub(/\/(lib|bin)\/?$/, '')
      else
        require 'rubygems'
        
        # fall back to using gem installation
        matches = Gem::source_index.find_name(app)
        raise LoadError, "#{app} gem doesn't appear to be installed!" if matches.empty?
        
        gem_spec = matches.last
        $APP_ROOT = gem_spec.full_gem_path
        
        gem(app)
      end
      
      $: <<  $APP_ROOT+"/lib"
      
      $PID_FILE     = @options[:pid_file]
      $CONFIG_FILE  = @options[:conf_file]
      $VERBOSE      = @options[:verbose]
      
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} app.rb"
        opts.define_head "#{File.basename($0)}, the microframework ON-button for ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
        opts.separator ""
        opts.separator "Application options:"
      
        opts.on("-d", "--daemonize", "Run daemonized in the background") do
          $DAEMONIZE = true
        end
        opts.on("-c", "--config FILE", "Use this config file (default is /etc/<app>/config.yml)") do |c| 
          puts "Using config file #{c.inspect}"
          $CONFIG_FILE = c
        end
        opts.on("-P", "--pid_file FILE", "Path to pid file (used only when running daemonized; default is /etc/<app>/<app>.pid)") do |p| 
          if $DAEMONIZE && !File.exists?(p)
            puts "Using pid file #{p.inspect}"
            $PID_FILE = p
          elsif File.exists?(p)
            puts "The pid file already exists.  Is #{app} running?\n" +
              "You will have to first manually remove the pid file at '#{p}' to start the server as a daemon."
            exit 1
          else
            puts "Not running as daemon.  Ignoring pid option"
          end
        end
        
        # optoinal block with additonal opts.on() calls specific to your application
        if @options[:extra_cli_options]
          @options[:extra_cli_options].call(opts)
        end   
      
        opts.separator ""
        opts.separator "Picnic options:"
      
        # No argument, shows at tail.  This will print an options summary.
        # Try it and see!
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
        
        opts.on_tail("-v", "--version", "Show the application's version number") do
          require "#{$APP_ROOT}/lib/#{app}/version.rb"
          app_mod = Object.const_get(@options[:app_module])
          puts "#{app}-#{app_mod::VERSION::STRING}"
          exit
        end
      end
      
      begin
        opts.parse! ARGV
      rescue OptionParser::ParseError => ex
        STDERR.puts "!! #{ex.message}"
        puts "** use `#{File.basename($0)} --help` for more details..."
        exit 1
      end
      
      
      $CONF = Picnic::Conf.new
      $CONF.load_from_file(app, $APP_ROOT, $CONF_FILE)
      
      if $DAEMONIZE
        # TODO: use Process.daemon when RUBY_VERSION >= 1.9
        
        exit if fork
        Process.setsid
        exit if fork
        
        Dir.chdir $APP_ROOT
        File.umask 0000
        
        STDIN.reopen "/dev/null"
        STDOUT.reopen "/dev/null", "a"
        STDERR.reopen "/dev/null", "a"
        
        if $PID_FILE
          File.open($PID_FILE, 'w'){ |f| f.write("#{Process.pid}") }
          at_exit { File.delete($PID_FILE) if File.exist?($PID_FILE) }
        end
      end
      
      server = Picnic::Server::Base.new($CONF, [options[:app_file]])
      server.start
    end
  end
end


