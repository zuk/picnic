require 'active_support'

module Picnic
  # Provides an interface for accessing your Picnic app's configuration file.
  #
  # Usage example:
  #
  #   # Load the configuration from /etc/foo/config.yml
  #   Conf.load('foo')
  #
  #   # The contents of config.yml is now available as follows:
  #   puts Conf[:server]
  #   puts Conf[:authentication][:username]
  #   # ... etc.
  class Conf
    def initialize(from_hash = {})
      @conf = HashWithIndifferentAccess.new(from_hash)
      
      @conf[:log] ||= HashWithIndifferentAccess.new
      @conf[:log].merge!(:file => STDOUT, :level => 'DEBUG')
      
      @conf[:uri_path] ||= "/"
    end
    
    # Read a configuration option.
    #
    # For example:
    #   puts conf[:server]
    def [](key)
      @conf[key]
    end
    
    # Set a configuration option.
    #
    # For example:
    #   conf[:server] = 'mongrel'
    def []=(key, value)
      @conf[key] = value
    end
    
    # Another way of reading or writing a configuration option.
    #
    # The following statements are equivalent:
    #   puts conf[:server]
    #   puts conf.server
    #
    # These are also equivalent:
    #   conf[:server] = 'mongrel'
    #   conf.server = 'mongrel'
    def method_missing(method, *args)
      if method.to_s =~ /(.*?)=$/
        self[$~[1]] = args.first
      else
        self[method]
      end
    end
    
    # Needs to be defined when we have a custom method_missing().
    def respond_to?(method)
      (@conf.stringify_keys.keys).include?(method.to_s) || super
    end
    
    # Returns the path to your application's example config file.
    #
    # The example config file should be in the root directory of
    # your application's distribution package and should be called
    # <tt>config.example.yml</tt>. This file is used as a template
    # for your app's configuration, to be customized by the end
    # user. 
    def example_config_file_path(app_root)
      "#{app_root}/config.example.yml"
    end
    
    # Copies the example config file into the appropriate
    # configuration directory.
    #
    # +app_name+:: The name of your application. For example: <tt>foo</tt>
    # +app_root+:: The path to your application's root directory. For example: <tt>/srv/www/camping/foo/</tt>
    # +dest_conf_file:: The path where the example conf file should be copied to.
    #                   For example: <tt>/etc/foo/config.yml</tt>
    def copy_example_config_file(app_name, app_root, dest_conf_file)
      require 'fileutils'
          
      example_conf_file = example_config_file_path(app_root)
      
      puts "\n#{app_name.to_s.upcase} SERVER HAS NOT YET BEEN CONFIGURED!!!\n"
      puts "\nAttempting to copy sample configuration from '#{example_conf_file}' to '#{dest_conf_file}'...\n"
      
      unless File.exists? example_conf_file 
        puts "\nThe example conf file does not exist! The author of #{app_name} may have forgotten to include it. You'll have to create the config file manually.\n"
        exit 2
      end
      
      begin
        dest_conf_file_dir = File.dirname(dest_conf_file)
        FileUtils.mkpath(dest_conf_file_dir) unless File.exists? dest_conf_file_dir
        FileUtils.cp(example_conf_file, dest_conf_file)
      rescue Errno::EACCES
        puts "\nIt appears that you do not have permissions to create the '#{dest_conf_file}' file. Try running this command using sudo (as root).\n"
        exit 2
      rescue => e
        puts "\nFor some reason the '#{dest_conf_file}' file could not be created (#{e})."
        puts "You'll have to copy the file manually. Use '#{example_conf_file}' as a template.\n"  
        exit 2
      end
      
      puts "\nA sample configuration has been created for you in '#{dest_conf_file}'. Please edit this file to" +
        " suit your needs and then run #{app_name} again.\n"
      exit 1
    end
    
    # Loads the configuration from the YAML file for the given app.
    #
    # <tt>app_name</tt> should be the name of your app; for example: <tt>foo</tt>
    # <tt>app_root</tt> should be the path to your application's root directory; for example:: <tt>/srv/www/camping/foo/</tt>
    # [<tt>config_file</tt>] can be the path to an alternate location for the config file to load
    #
    # By default, the configuration will be loaded from <tt>/etc/<app_name>/config.yml</tt>.
    def load_from_file(app_name, app_root, config_file = nil)
      conf_file = config_file || "/etc/#{app_name.to_s.downcase}/config.yml"
      
      puts "Loading configuration for #{app_name.inspect} from #{conf_file.inspect}..."
      
      begin
        conf_file = etc_conf = conf_file
        unless File.exists? conf_file 
          # can use local config.yml file in case we're running non-gem installation
          conf_file = "#{app_root}/config.yml"
        end
      
        unless File.exists? conf_file  
          copy_example_config_file(app_name, app_root, etc_conf)
        end
        
        loaded_conf = HashWithIndifferentAccess.new(YAML.load_file(conf_file))
        
        @conf.merge!(loaded_conf)
        
      rescue => e
          raise "Your #{app_name} configuration may be invalid."+
            " Please double-check check your config.yml file."+
            " Make sure that you are using spaces instead of tabs for your indentation!!" +
            "\n\nTHE UNDERLYING ERROR WAS:\n#{e.inspect}"
      end
    end
    
    def merge_defaults(defaults)
      @conf = HashWithIndifferentAccess.new(HashWithIndifferentAccess.new(defaults).merge(@conf))
    end
  end
end
