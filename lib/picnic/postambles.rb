module Picnic
  module Postambles
    
    def webrick
      require 'webrick/httpserver'
      require 'webrick/https'
      require 'camping/webrick'
      
      # TODO: verify the certificate's validity
      # example of how to do this is here: http://pablotron.org/download/ruri-20050331.rb
      
      cert_path = Picnic::Conf.ssl_cert
      key_path = Picnic::Conf.ssl_key || Picnic::Conf.ssl_cert
        # look for the key in the ssl_cert if no ssl_key is specified
            
      begin
        s = WEBrick::HTTPServer.new(
          :BindAddress => "0.0.0.0",
          :Port => Picnic::Conf.port
        )
      rescue Errno::EACCES
        puts "\nThe server could not launch. Are you running on a privileged port? (e.g. port 443) If so, you must run the server as root."
        exit 2
      end
      
      self.create
      s.mount "#{Picnic::Conf.uri_path}", WEBrick::CampingHandler, self
    
      # This lets Ctrl+C shut down your server
      trap(:INT) do
        s.shutdown
      end
      trap(:TERM) do
        s.shutdown
      end
            
      if $DAEMONIZE
        puts "\n** #{self} will run at http://#{ENV['HOSTNAME'] || 'localhost'}:#{Picnic::Conf.port}#{Picnic::Conf.uri_path} and log to #{Picnic::Conf.log[:file].inspect}. "
        puts "** Check the log file for further messages!\n\n"
        
        logdev = $LOG.instance_variable_get(:@logdev).instance_variable_get(:@filename)
        if logdev == 'STDOUT' || logdev == nil
          puts "\n!!! Warning !!!\nLogging to the console (STDOUT) is not possible once the server daemonizes. "+
            "You should change the logger configuration to point to a real file."
        end
        
        WEBrick::Daemon.start do
          begin
            write_pid_file if $PID_FILE
            $LOG.info "Starting #{self} as a WEBrick daemon with process id #{Process.pid}."
            s.start
            $LOG.info "Stopping #{self} WEBrick daemon with process id #{Process.pid}."
            clear_pid_file
          rescue => e
            $LOG.error e
            raise e
          end
        end
      else
        puts "\n** #{self} is running at http://#{ENV['HOSTNAME'] || 'localhost'}:#{Picnic::Conf.port}#{Picnic::Conf.uri_path} and logging to #{Picnic::Conf.log[:file].inspect}\n\n"
        
        s.start
      end
    end
    
    def mongrel
      require 'rubygems'
      require 'mongrel/camping'
      
      if $DAEMONIZE
        # check if log and pid are writable before daemonizing, otherwise we won't be able to notify
        # the user if we run into trouble later (since once daemonized, we can't write to stdout/stderr)
        check_pid_writable if $PID_FILE
        check_log_writable
      end
      
      self.create
      
      puts "\n** #{self} is starting. Look in #{Picnic::Conf.log[:file].inspect} for further notices."
      
      settings = {:host => "0.0.0.0", :log_file => Picnic::Conf.log[:file], :cwd => $APP_PATH}
      
      # need to close all IOs before daemonizing
      $LOG.close if $DAEMONIZE
      
      begin
        app_mod = self
        config = Mongrel::Configurator.new settings  do
          daemonize :log_file => Picnic::Conf.log[:file], :cwd => $APP_PATH if $DAEMONIZE
          
          listener :port => Picnic::Conf.port do
            uri Picnic::Conf.uri_path, :handler => Mongrel::Camping::CampingHandler.new(app_mod)
            setup_signals
          end
        end
      rescue Errno::EADDRINUSE
        exit 1
      end
      
      config.run
      
      self.init_logger
      #self.init_db_logger
      
      if $DAEMONIZE && $PID_FILE
        write_pid_file
        unless File.exists? $PID_FILE
          $LOG.error "#{self} could not start because pid file #{$PID_FILE.inspect} could not be created."
          exit 1
        end
      end
      
      puts "\n** #{self} is running at http://#{ENV['HOSTNAME'] || 'localhost'}:#{Picnic::Conf.port}#{Picnic::Conf.uri_path} and logging to '#{Picnic::Conf.log[:file]}'"
      config.join

      clear_pid_file

      puts "\n** #{self} is stopped (#{Time.now})"
    end
    
    
    def fastcgi
      require 'camping/fastcgi'
      Dir.chdir('/srv/www/camping/fluxr/')
      
      self.create
      Camping::FastCGI.start(self)
    end
    
    
    def cgi
      self.create
      puts self.run
    end
    
    private
    def check_log_writable
      log_file = Picnic::Conf.log['file']
      begin
        f = open(log_file, 'w')
      rescue
        $stderr.puts "Couldn't write to log file at '#{log_file}' (#{$!})."
        exit 1
      end
      f.close
    end
    
    def check_pid_writable
      $LOG.debug "Checking if pid file #{$PID_FILE.inspect} is writable"
      begin        
        f = open($PID_FILE, 'w')
      rescue
        $stderr.puts "Couldn't write to log at #{$PID_FILE.inspect} (#{$!})."
        exit 1
      end
      f.close
    end
    
    def write_pid_file
      $LOG.debug "Writing pid #{Process.pid.inspect} to pid file #{$PID_FILE.inspect}"
      open($PID_FILE, "w") { |file| file.write(Process.pid) }
    end
    
    def clear_pid_file
      if $PID_FILE && File.exists?($PID_FILE)
        $LOG.debug "Clearing pid file #{$PID_FILE.inspect}"
        File.unlink $PID_FILE
      end
    end
  
  end
end
