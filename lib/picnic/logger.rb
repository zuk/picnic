require 'logger'

module Picnic
  module Logger
    
    # Makes available a Logger instance under the global $LOG variable.
    def init_global_logger!
      logdev = ($CONF && $CONF.log[:file]) || STDOUT
      $LOG = Picnic::Logger::Base.new(logdev)
      $LOG.level = Picnic::Logger::Base.const_get(($CONF && $CONF.log[:level]) || 'DEBUG')
      
      puts "Initialized global logger to #{logdev.inspect}."
    end
    module_function :init_global_logger!
    
    class Base < ::Logger
      def initialize(logdev, shift_age = 0, shift_size = 1048576)
        begin
          super
        rescue Exception
          puts "WARNING: Couldn't create Logger with output '#{logdev}'. Logger output will be redirected to STDOUT."
          super(STDOUT, shift_age, shift_size)
        end
      end
    
      def format_message(severity, datetime, progrname, msg)
        (@formatter || @default_formatter).call(severity, datetime, progname, msg)
      end
    end
  
    # Custom log formatter used by the Picnic Logger.
    class Formatter < ::Logger::Formatter
      Format = "[%s#%d] %5s -- %s: %s\n"
      
      def call(severity, time, progname, msg)
        Format % [format_datetime(time), $$, severity, progname,
          msg2str(msg)]
      end
    end
  end
end