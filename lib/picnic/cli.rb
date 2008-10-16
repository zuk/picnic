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
  #     :app_path => File.expand_path(File.dirname(File.expand_path(__FILE__)))
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
    #             +app_path+:: The path to your application's main Ruby file.
    #                          By default this is expected to be <tt>../lib/<app>.rb</tt>
    #             +pid_file+:: Where the app's PID file (containing the app's
    #                          process ID) should be placed. By default this is
    #                          <tt>/etc/<app>/<app>.pid</tt>
    #             +verbose+::  True if the cli handler should report
    #                          everything that it's doing to STDOUT. 
    def initialize(app, options = {})
      @app = app
      
      @options = options || {}
      @options[:app_path]   ||= File.expand_path(File.dirname(File.expand_path(__FILE__))+"/../lib/#{app}.rb")
      @options[:app_module] ||= app.capitalize
      @options[:pid_file]   ||= "/etc/#{app}/#{app}.pid"
      @options[:conf_file]  ||= nil
      @options[:verbose]    ||= false
    end
    
    # Parses command line options given to the script.
    def handle_cli_input
      if File.exists? options[:app_path]
        # try to use given app base path
        $: << File.dirname(options[:app_path])
        path = File.dirname(options[:app_path])+"/"
      else
        # fall back to using gem installation
        path = ""
        require 'rubygems'
        gem(app)
      end
      
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
          require "#{path}/lib/#{app}/version"
          app_mod = @options[:app_module].constantize
          puts "#{app}-#{app_mod::VERSION::STRING}"
          exit
        end
      end.parse!
      
      $APP_PATH = options[:app_path]
      
      load "#{path}/lib/#{app}.rb"
    end
  end
end


