$: << File.dirname(File.expand_path(__FILE__))
$: << File.dirname(File.expand_path(__FILE__))+"/../vendor/camping-1.5.180/lib"


require 'camping'


require 'active_support' unless Object.const_defined?(:ActiveSupport)

require 'picnic/utils'
require 'picnic/conf'
require 'picnic/postambles'
require 'picnic/controllers'




class Module
  
  def picnic!
    include Picnic
    
    puts "Adding Picnic functionality to #{self}..."
    self.module_eval do
      def init_logger
        puts "Initializing #{self} logger..."
        $LOG = self::Utils::Logger.new(self::Conf.log[:file])
        $LOG.level = "#{self}::Utils::Logger::#{self::Conf.log[:level]}".constantize
      end
      module_function :init_logger
      
      def init_db_logger
        begin
          if self::Conf.db_log
            log_file = self::Conf.db_log[:file] || "#{self.to_s.downcase}_db.log"
            self::Models::Base.logger = Logger.new(log_file)
            self::Models::Base.logger.level = "#{self}::Utils::Logger::#{self::Conf.db_log[:level] || 'DEBUG'}".constantize
          end
        rescue Errno::EACCES => e
          $LOG.warn "Can't write to database log file at '#{log_file}': #{e}"
        end
      end
      module_function :init_db_logger
      
      def authenticate_using(mod)
        require 'picnic/authentication'
        mod = "#{self}::Authentication::#{mod.to_s.camelize}".constantize unless mod.kind_of? Module
        
        $LOG.info("Enabling authentication for all requests using #{mod.inspect}.")
        
        module_eval do
          include mod
        end
      end
      module_function :authenticate_using
    
      def start_picnic
          #Fluxr::Models::Base.establish_connection(Fluxr::Conf.database)
          #Fluxr.init_db_logger unless Fluxr::Conf.server.to_s == 'mongrel'
          
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