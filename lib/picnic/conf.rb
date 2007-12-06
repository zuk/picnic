module Picnic
  class Conf
    $CONF ||= HashWithIndifferentAccess.new
    $CONF[:log] ||= HashWithIndifferentAccess.new
    $CONF[:log][:file]  ||= STDOUT
    $CONF[:log][:level] ||= 'DEBUG'
    $CONF[:uri_path]    ||= "/"
    $CONF[:base_dir]    ||= "."
    
    def self.[](key)
      $CONF[key]
    end
    
    def self.method_missing(method, *args)
      self[method]
    end
    
    def self.example_config_file_path
      caller.last =~ /^(.*?):\d+$/
      File.dirname(File.expand_path($1))+'/../config.example.yml'
    end
    
    def self.copy_example_config_file(app, dest_conf_file)
      require 'fileutils'
          
      example_conf_file = example_config_file_path
      
      puts "\n#{app.to_s.upcase} SERVER HAS NOT YET BEEN CONFIGURED!!!\n"
      puts "\nAttempting to copy sample configuration from '#{example_conf_file}' to '#{dest_conf_file}'...\n"
      
      unless File.exists? example_conf_file 
        puts "\nThe example conf file does not exist! The author of #{app} may have forgotten to include it. You'll have to create the config file manually.\n"
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
        " suit your needs and then run #{app} again.\n"
      exit 1
    end
    
    def self.load(app)
      
      conf_file = $CONFIG_FILE || "/etc/#{app.to_s.downcase}/config.yml"
      
      puts "Loading configuration for #{app} from '#{conf_file}'..."
      
      begin
        conf_file = etc_conf = conf_file
        unless File.exists? conf_file 
          # can use local config.yml file in case we're running non-gem installation
          conf_file = File.dirname(File.expand_path(__FILE__))+"/../../config.yml"
        end
      
        unless File.exists? conf_file  
          copy_example_config_file(app, etc_conf)
        end
        
        loaded_conf = HashWithIndifferentAccess.new(YAML.load_file(conf_file))
        
        if $CONF
          $CONF = HashWithIndifferentAccess.new($CONF)
          $CONF = $CONF.merge(loaded_conf)
        else
          $CONF = loaded_conf
        end
        
        $CONF[:log][:file] = STDOUT unless $CONF[:log][:file]
        
      rescue
          raise "Your #{app} configuration may be invalid."+
            " Please double-check check your config.yml file."+
            " Make sure that you are using spaces instead of tabs for your indentation!!" +
            "\n\nTHE UNDERLYING ERROR WAS:\n#{$!}"
      end
    end
  end
end
