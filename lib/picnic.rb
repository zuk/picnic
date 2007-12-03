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
        $LOG = Picnic::Utils::Logger.new(Picnic::Conf.log[:file])
        $LOG.level = "Picnic::Utils::Logger::#{Picnic::Conf.log[:level]}".constantize
      end
      module_function :init_logger
      
      def init_db_logger
        begin
          if Picnic::Conf.db_log
            log_file = Picnic::Conf.db_log[:file] || "#{self.to_s.downcase}_db.log"
            self::Models::Base.logger = Logger.new(log_file)
            self::Models::Base.logger.level = "Picnic::Utils::Logger::#{Picnic::Conf.db_log[:level] || 'DEBUG'}".constantize
          end
        rescue Errno::EACCES => e
          $LOG.warn "Can't write to database log file at '#{log_file}': #{e}"
        end
      end
      module_function :init_db_logger
    
      def start_picnic
          #Fluxr::Models::Base.establish_connection(Fluxr::Conf.database)
          #Fluxr.init_db_logger unless Fluxr::Conf.server.to_s == 'mongrel'
          
          require 'picnic/postambles'
          self.extend Picnic::Postambles
          
          if $PID_FILE && !(Picnic::Conf.server.to_s == 'mongrel' || Picnic::Conf.server.to_s == 'webrick')
            $LOG.warn("Unable to create a pid file. You must use mongrel or webrick for this feature.")
          end
        
        #  begin
            raise NoMethodError if Picnic::Conf.server.nil?
            send(Picnic::Conf.server)
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
    
    Picnic::Conf.load(self)
    init_logger
  end
end