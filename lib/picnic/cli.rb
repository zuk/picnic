require 'optparse'

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
    #             +verbose+::  True if the cli handler should report
    #                          everything that it's doing to STDOUT. 
    def initialize(app, options = {})
      @app = app
      
      @options = options || {}
      @options[:app_file]   ||= File.expand_path(File.dirname(File.expand_path($0))+"/../lib/#{app}.rb")
      @options[:app_module] ||= app.capitalize
      @options[:pid_file]   ||= "/etc/#{app}/#{app}.pid"
      @options[:conf_file]  ||= nil
      @options[:verbose]    ||= false
    end
    
    # Parses command line options given to the script.
    def handle_cli_input
      if File.exists? options[:app_file]
        # try to use given app base path
        $APP_PATH = File.dirname(options[:app_file]).gsub(/\/lib\/?$/, '')
      else
        require 'rubygems'
        
        # fall back to using gem installation
        matches = Gem::source_index.find_name(app)
        raise LoadError, "#{app} gem doesn't appear to be installed!" if matches.empty?
        
        gem_spec = matches.last
        $APP_PATH = gem_spec.full_gem_path
        
        gem(app)
      end
      
      $: <<  $APP_PATH+"/lib"
      
      $PID_FILE = "/etc/#{app}/#{app}.pid" 
      
      OptionParser.new do |opts|
        opts.banner = "Usage: #{app} [options]"
      
        opts.on("-c", "--config FILE", "Use config file (default is /etc/#{app}/config.yml)") do |c|
          puts "Using config file #{c}"
          $CONFIG_FILE = c
        end
        
        opts.on("-d", "--daemonize", "Run as a daemon (only when using webrick or mongrel)") do |c|
          $DAEMONIZE = true
        end
      
        opts.on("-P", "--pid_file FILE", "Use pid file (default is /etc/#{app}/#{app}.pid)") do |c|
          if $DAEMONIZE && !File.exists?(c)
            puts "Using pid file '#{c}'"
            $PID_FILE = c
          elsif File.exists?(c)
            puts "The pid file already exists.  Is #{app} running?\n" +
              "You will have to first manually remove the pid file at '#{c}' to start the server as a daemon."
            exit 1
          else
            puts "Not running as daemon.  Ignoring pid option"
          end
        end
 
        # :extra_cli_options should be a block with additonal app-specific opts.on() calls
        if @options[:extra_cli_options]
          @options[:extra_cli_options].call(opts)
        end     

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
        
        opts.on_tail("-V", "--version", "Show version number") do
          load "#{$APP_PATH}/lib/#{app}/version.rb"
          app_mod = Object.const_get(@options[:app_module])
          puts "#{app}-#{app_mod::VERSION::STRING}"
          exit
        end
      end.parse!
      
      load "#{$APP_PATH}/lib/#{app}.rb"
    end
  end
end


