require 'optparse'

module Picnic
  
  # Provides functionality for controlling a Picnic-based server as 
  # an init.d service. 
  #
  # Based on code from rubycas-server by jzylks and matt.zukowski.
  #
  # Usage Example:
  #
  #   #!/usr/bin/env ruby
  #   
  #   require 'rubygems'
  #   require 'picnic/service_control'
  #
  #   ctl = Picnic::ServiceControl.new('foo')
  #   ctl.handle_cli_input
  #
  # The file containing this code can now be used to control the Picnic
  # app 'foo'.
  #
  # For, example, lets say you put this in a file called <tt>foo-ctl</tt>. 
  # You can now use <tt>foo-ctl</tt> on the command line as follows:
  #
  #   chmod +x foo-ctl
  #   ./foo-ctl -h
  #   ./foo-ctl start --verbose --config /etc/foo/config.yml
  #   ./foo-ctl stop --config /etc/foo/config.yml
  #
  # Your <tt>foo-ctl</tt> script can also be used as part of Linux's init.d
  # mechanism for launching system services. To do this, create the file
  # <tt>/etc/init.d/foo</tt> and make sure that it is executable. It will
  # look something like the following (this may vary depending on your Linux
  # distribution; this example is for SuSE):
  #
  #   #!/bin/sh
  #   CTL=foo-ctl
  #   . /etc/rc.status
  #
  #   rc_reset
  #   case "$1" in
  #       start)
  #           $CTL start
  #           rc_status -v
  #           ;;
  #       stop)
  #           $CTL stop
  #           rc_status -v
  #           ;;
  #       restart)
  #           $0 stop
  #           $0 start
  #           rc_status
  #           ;;
  #       status)
  #           $CTL status
  #           rc_status -v
  #           ;;
  #       *)
  #           echo "Usage: $0 {start|stop|status|restart}
  #           exit 1
  #           ;;
  #   esac
  #   rc_exit
  #
  # You should now be able to launch your application like any other init.d script
  # (just make sure that <tt>foo-ctl</tt> is installed in your executable <tt>PATH</tt>
  # -- if your application is properly installed as a RubyGem, this will be done automatically).
  #
  # On most Linux systems, you can make your app start up automatically during boot by calling:
  # 
  #   chkconfig -a foo
  #
  # On Debian and Ubuntu, it's:
  #
  #   update-rc.d foo defaults
  #
  class ServiceControl
    
    attr_accessor :app, :options
    
    # Creates a new service controller.
    #
    # +app+:: The name of the application. This should match the name of the
    #         binary, which by default is expected to be in the same directory
    #         as the service control script.
    # +options+:: A hash overriding default options. The options are:
    #             +bin_file+:: The name of the binary file that this control
    #                          script will use to start and stop your app.
    #             +pid_file+:: Where the app's PID file (containing the app's
    #                          process ID) should be placed.
    #             +verbose+::  True if the service control script should report
    #                          everything that it's doing to STDOUT.  
    def initialize(app, options = {})
      @app = app
      
      @options = options
      @options[:bin_file]  ||= "./#{app}"
      @options[:pid_file]  ||= "/etc/#{app}/#{app}.pid"
      @options[:conf_file] ||= nil
      @options[:verbose]   ||= false
      
      @options = options
    end
    
    # Parses command line options given to the service control script.
    def handle_cli_input
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} (start|stop|restart) [options]"
        opts.banner += "\n#{app} is only usable when using webrick or mongrel"
       
        opts.on("-c", "--config FILE", "Path to #{app} configuration file") { |value| @options[:conf_file] = value }
        opts.on("-P", "--pid_file FILE", "Path to #{app} pid file") { |value| @options[:pid_file] = value }
        opts.on('-v', '--verbose', "Print debugging information to the console") { |value| @options[:verbose] = value }
      
        if ARGV.empty?
          puts opts
          exit
        else
          @cmd = opts.parse!(ARGV)
          if @cmd.nil?
            puts opts
            exit
          end
        end
      end
      
      if !@options[:conf_file].nil? && !File.exists?(@options[:conf_file])
        puts "Invalid path to #{app} configuration file: #{@options[:conf_file]}"
        exit
      end
      
      case @cmd[0]
      when "start": 
        puts "Starting #{app}..."
        start
      when "stop":
        puts "Stopping #{app}..."
        stop
      when "restart":
        puts "Restarting #{app}..."
        stop
        start
      when "status":
        puts "Checking status of #{app}..."
        status
      else
       puts "Invalid command. Usage: #{app}-ctl [-cPv] start|stop|restart|status"
      end
      
      exit
    end
    
    def start
      # use local app bin if it exists and is executable -- makes debugging easier
      bin = options[:bin_file]
      
      if File.exists?(bin)
        exec = "ruby #{bin}"
      else
        exec = app
      end
      
      case get_state
      when :ok
        $stderr.puts "#{app} is already running"
        exit 1
      when :not_running, :empty_pid
        $stderr.puts "The pid file '#{@options[:pid_file]}' exists but #{app} is not running." +
          " The pid file will be automatically deleted for you, but this shouldn't have happened!"
        File.delete(@options[:pid_file])
      when :dead
        $stderr.puts "The pid file '#{@options[:pid_file]}' exists but #{app} is not running." +
          " Please delete the pid file first."
        exit 1
      when :missing_pid
        # we should be good to go (unless the server is already running without a pid file)
      else
        $stderr.puts "#{app} could not be started. Try looking in the log file for more info."
        exit 1
      end
        
      cmd = "#{exec} -d -P #{@options[:pid_file]}"
      cmd += " -c #{@options[:conf_file]}" if !@options[:conf_file].nil?
      
      puts ">>> #{cmd}" if @options[:verbose]
      
      output = `#{cmd}`
      
      puts "<<< #{output}" if @options[:verbose]
      
      if s = get_state == :ok
        exit 0
      else
        $stderr.puts "#{app} could not start properly! (#{s})\nTry running with the --verbose option for details." 
        case s
        when :missing_pid
          exit 4
        when :not_running
          exit 3
        when :dead
          exit 1
        else
          exit 4
        end
      end
    end
    
    def stop
      if File.exists? @options[:pid_file]
        pid = open(@options[:pid_file]).read.to_i
        begin
          Process.kill("TERM", pid)
          exit 0
        rescue Errno::ESRCH
          $stderr.puts "#{app} process '#{pid}' does not exist."
          exit 1
        end
      else
        $stderr.puts "#{@options[:pid_file]} not found.  Is #{app} running?"
        exit 4
      end
    end
    
    def status
      case get_state
      when :ok
        puts "#{app} appears to be up and running."
        exit 0
      when :missing_pid
        $stderr.puts "#{app} does not appear to be running (pid file not found)."
        exit 3
      when :empty_pid
        $stderr.puts "#{app} does not appear to be running (pid file exists but is empty)."
      when :not_running
        $stderr.puts "#{app} is not running."
        exit 1
      when :dead
        $stderr.puts "#{app} is dead or unresponsive."
        exit 102
      end
    end
    
    def get_state
      if File.exists? @options[:pid_file]
        pid = File.read(@options[:pid_file]).strip
        
        return :empty_pid unless pid and !pid.empty? # pid file exists but is empty
        
        state = `ps -p #{pid} -o state=`.strip
        if state == ''
          return :not_running
        elsif state == 'R' || state == 'S'
          return :ok
        else
          return :dead
        end
      else
        # TODO: scan through the process table to see if server is running without pid file
        return :missing_pid
      end
    end
  end
end