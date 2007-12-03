require 'optparse'

module Picnic
  
  # Provides functionality for controlling a Picnic-based server as 
  # an init.d service. 
  #
  # Based on code from rubycas-server by jzylks and matt.zukowski.
  class ServiceControl
    
    attr_accessor :app, :options
    
    def initialize(app, options = {})
      @app = app
      
      @options = {}
      @options[:pid_file]  ||= "/etc/#{app}/#{app}.pid"
      @options[:conf_file] ||= nil
      @options[:verbose]   ||= false
      
      @options = options
    end
    
    def parse_cli_opts
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
      bin = File.dirname(File.expand_path(__FILE__)) + "/#{app}"
    
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