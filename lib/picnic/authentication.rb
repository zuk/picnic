module Picnic #:nodoc:
  # These modules (currently only one module, but more in the future) provide authentication
  # for your Camping app. 
  #
  # This code is based on Camping::BasicAuth written by Manfred Stienstra 
  # (see http://www.fngtps.com/2006/05/basic-authentication-for-camping).
  #
  # ----
  #
  # Picnic::Authentication::Basic can be mixed into a camping application to get Basic Authentication 
  # support in the application. The module defines a <tt>service</tt> method that only continues 
  # the request chain when proper credentials are given.
  # 
  # == Getting Started
  #
  # To activate Basic Authentication for your application:
  #
  # 1. Picnic-fy your Camping app (e.g: <tt>Camping.goes :your_app; YourApp.picnic!</tt>)
  # 2. Call <tt>authenticate_using <module></tt> (e.g: <tt>YourApp.authenticate_using :basic</tt>)
  # 3. Define an <tt>authenticate</tt> method on your application module that takes a hash.
  #    The hash contains credentials like <tt>:username</tt>, <tt>:password</tt>, and <tt>:hostname</tt>,
  #    although future authentication modules may submit other credentials.
  #    The <tt>authenticate</tt> method should return true when the credentials are valid.
  #    Examples:
  #
  #      module Blog
  #        def authenticate(credentials)
  #          credentials[:username] == 'admin' &&
  #            credentials[:password] == 'flapper30'
  #        end
  #        module_function :authenticate
  #      end
  #
  #    or
  #
  #      module Wiki
  #        def authenticate(credentials)
  #          u = credentials[:username]
  #          p = credentials[:password]
  #          Models::User.find_by_username_and_password u, p
  #        end
  #        module_function :authenticate
  #      end
  #
  # 4. <tt>service</tt> sets <tt>@credentials</tt> to the credentials of the person who logged in.
  module Authentication
    module Basic
      require 'base64'
      
      # Reads the username and password from the headers and returns them.
      def read_credentials
        if d = %w{REDIRECT_X_HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION HTTP_AUTHORIZATION}.inject([]) \
          { |d,h| env.has_key?(h) ? env[h].to_s.split : d }
          u,p = ::Base64.decode64(d[1]).split(':')[0..1] if d[0] == 'Basic'
          return {:username => u, :password => p}
        end
      end
      
      # The <tt>service</tt> method, when mixed into your application module, wraps around the
      # <tt>service</tt> method defined by Camping. It halts execution of the controllers when
      # your <tt>authenticate</tt> method returns false. See the module documentation how to
      # define your own <tt>authenticate</tt> method.
      def service(*a)
        @credentials = read_credentials || {}
        app = self.class.name.gsub(/^(\w+)::.+$/, '\1')
        if Kernel.const_get(app).authenticate(@credentials)
          s = super(*a)
        else
          @status = 401
          @headers['Content-type'] = @headers['Content-type'] || 'text/plain'
          @headers['Status'] = 'Unauthorized'
          @headers['WWW-Authenticate'] = "Basic realm=\"#{app}\""
          @body = 'Unauthorized'
          s = self
        end
        s
      end
    end
  end
end