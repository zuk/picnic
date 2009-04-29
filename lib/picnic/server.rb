require 'camping/server'

module Picnic::Server
  class Base < Camping::Server
    def start
      handler, conf = case @conf.server
      when "console"
        ARGV.clear
        IRB.start
        exit
      when "mongrel"
        prep_mongrel
      when "webrick"
        prep_webrick
      end

      # preload the apps in order to show any startup errors when
      # the app is run from the command line (otherwise they would only
      # show up after the first request to the web server)
      reload!
            
      handler.run(self, conf) 
    end


    def app
      reload!
       
      rapp =  apps.values.first

      if @conf.uri_path
        rapp = Rack::URLMap.new(@conf.uri_path => rapp)
      end
      
      rapp = Rack::Static.new(rapp, @conf[:static]) if @conf[:static]
      rapp = Rack::ContentLength.new(rapp)
      rapp = Rack::Lint.new(rapp)
      rapp = Camping::Server::XSendfile.new(rapp)
      rapp = Rack::ShowExceptions.new(rapp)
    end
    
    
    private
    
    def prep_webrick
      handler = Rack::Handler::WEBrick
      options = {
        :BindAddress => @conf.bind_address || "0.0.0.0",
        :Port => @conf.port
      }
      
      cert_path = @conf.ssl_cert
      key_path = @conf.ssl_key || @conf.ssl_cert
        # look for the key in the ssl_cert if no ssl_key is specified
        
      unless cert_path.nil? && key_path.nil?
        raise "The specified certificate file #{cert_path.inspect} does not exist or is not readable. " +
          " Your 'ssl_cert' configuration setting must be a path to a valid " +
          " ssl certificate." unless
            File.exists? cert_path
        
        raise "The specified key file #{key_path.inspect} does not exist or is not readable. " +
          " Your 'ssl_key' configuration setting must be a path to a valid " +
          " ssl private key." unless
            File.exists? key_path
            
        require 'openssl'
        require 'webrick/https'
        
        cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
        key = OpenSSL::PKey::RSA.new(File.read(key_path))
        
        options[:SSLEnable] = true
        options[:SSLVerifyClient] = ::OpenSSL::SSL::VERIFY_NONE
        options[:SSLCertificate] = cert
        options[:SSLPrivateKey] = key
      end
      
      return handler, options
    end
    
    
    def prep_mongrel
      handler = Rack::Handler::Mongrel
      options = {
        :Host => @conf.bind_address || "0.0.0.0", 
        :Port => @conf.port
      }
      
      return handler, options
    end
    
  end
  
end
