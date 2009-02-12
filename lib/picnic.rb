require 'rubygems'
require 'activesupport'

$: << File.dirname(__FILE__)
$: << File.dirname(__FILE__) + "/../vendor/camping-2.0.20090212/lib"

require "camping"


module Picnic
  
  def self.included(base)
    base.mod_eval do
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
        load "picnic/authentication.rb"
        mod = self::Authentication.const_get(mod.to_s.camelize) unless mod.kind_of? Module
        
        $LOG.info("Enabling authentication for all requests using #{mod.inspect}.")
        
        module_eval do
          include mod
        end
      end
      module_function :authenticate_using
    end
  end

end
