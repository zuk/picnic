$: << File.dirname(File.expand_path(__FILE__))
$: << File.dirname(File.expand_path(__FILE__))+"/../vendor/camping-1.5.180/lib"

unless Object.const_defined?(:ActiveSupport)
  begin
    require 'active_support'
  rescue LoadError
    require 'rubygems'
    gem 'activesupport', '>=2.0.2'
    gem 'activerecord', '>=2.0.2'
    require 'active_support'
  end
end

require 'camping'

require 'picnic/utils'
require 'picnic/conf'
require 'picnic/postambles'


class Module
  
  # Adds Picnic functionality to a Camping-enabled module.
  #
  # Example:
  #
  #   Camping.goes :Blog
  #   Blog.picnic!
  #
  # Your <tt>Blog</tt> Camping app now has Picnic functionality.
  def picnic!
    include Picnic
    
    puts "Adding Picnic functionality to #{self} from #{File.dirname(File.expand_path(__FILE__))}..."
    self.module_eval do
      # Initialize your application's logger. 
      # This is automatically done for you when you call #picnic!
      # The logger is initialized based on your <tt>:log</tt> configuration.
      # See <tt>config.example.yml</tt> for info on configuring the logger.
      def init_logger
        puts "Initializing #{self} logger..."
        $LOG = Picnic::Utils::Logger.new(self::Conf.log[:file])
        $LOG.level = Picnic::Utils::Logger.const_get(self::Conf.log[:level])
      end
      module_function :init_logger
      
      # Initialize your application's database logger. 
      # If enabled, all SQL queries going through ActiveRecord will be logged here.
      #
      # THIS SEEMS TO BE BROKEN RIGHT NOW and I can't really understand why.
      def init_db_logger
        begin
          if self::Conf.db_log
            log_file = self::Conf.db_log[:file] || "#{self.to_s.downcase}_db.log"
            self::Models::Base.logger = Picnic::Utils::Logger.new(log_file)
            self::Models::Base.logger.level = Picnic::Utils::Logger.const_get(self::Conf.db_log[:level] || 'DEBUG')
            $LOG.debug "Logging database queries to #{log_file.inspect}"
          end
        rescue Errno::EACCES => e
          $LOG.warn "Can't write to database log file at '#{log_file}': #{e}"
        end
      end
      module_function :init_db_logger
      
      # Enable authentication for your app.
      #
      # For example:
      #
      #   Camping.goes :Blog
      #   Blog.picnic!
      #
      #   $CONF[:authentication] ||= {:username => 'admin', :password => 'picnic'}
      #   Blog.authenticate_using :basic
      #
      #   module Blog
      #     def self.authenticate(credentials)
      #       credentials[:username] == Taskr::Conf[:authentication][:username] &&
      #         credentials[:password] == Taskr::Conf[:authentication][:password]
      #     end
      #   end
      #
      # Note that in the above example we use the authentication configuration from
      # your app's conf file.
      #
      def authenticate_using(mod)
        require 'picnic/authentication'
        mod = self::Authentication.const_get(mod.to_s.camelize) unless mod.kind_of? Module
        
        $LOG.info("Enabling authentication for all requests using #{mod.inspect}.")
        
        module_eval do
          include mod
        end
      end
      module_function :authenticate_using
    
      # Launches the web server to run your Picnic app.
      # This method will continue to run as long as your server is running.
      def start_picnic
          require 'picnic/postambles'
          self.extend self::Postambles
          
          if $PID_FILE && !(self::Conf.server.to_s == 'mongrel' || self::Conf.server.to_s == 'webrick')
            $LOG.warn("Unable to create a pid file. You must use mongrel or webrick for this feature.")
          end
          
          puts "\nStarting with configuration: #{$CONF.to_yaml}"
          puts
        
        #  begin
            raise NoMethodError if self::Conf.server.nil?
            send(self::Conf.server)
        #  rescue NoMethodError => e
        #    # FIXME: this rescue can sometime report the incorrect error messages due to other underlying problems
        #    #         raising a NoMethodError
        #    if Fluxr::Conf.server
        #      raise e, "The server setting '#{Fluxr::Conf.server}' in your config.yml file is invalid."
        #    else
        #      raise e, "You must have a 'server' setting in your config.yml file. Please see the Fluxr documentation."
        #    end
        #  end
      end
      module_function :start_picnic
      
      c = File.dirname(File.expand_path(__FILE__))+'/picnic/controllers.rb'
      p = IO.read(c).gsub("Picnic", self.to_s)
      eval p, TOPLEVEL_BINDING
      
    end
    
    self::Conf.load(self)
    init_logger
  end
end
