module Picnic #:nodoc:
  # These modules (currently only one module, but more in the future) provide authentication
  # for your Camping app. 
  #
  module Authentication
    # Picnic::Authentication::Basic provides Basic HTTP Authentication for your Camping app. 
    # The module defines a <tt>service</tt> method that only continues the request chain when 
    # proper credentials are provided by the client (browser).
    # 
    # == Getting Started
    #
    # To activate Basic Authentication for your application:
    #
    # 1. Picnic-fy your Camping app (e.g: <tt>Camping.goes :your_app; YourApp.picnic!</tt>)
    # 2. Call <tt>YourApp.authenticate_using :basic</tt>.
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
    #
    # ----
    #
    # This code is based on Camping::BasicAuth written by Manfred Stienstra 
    # (see http://www.fngtps.com/2006/05/basic-authentication-for-camping).
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
      
      def service(*a)
        app = Kernel.const_get self.class.name.gsub(/^(\w+)::.+$/, '\1')
        unless app.methods.include? :authenticate
          raise "Basic authentication is enabled but the 'authenticate' method has not been defined."
        end
        
        @credentials = read_credentials || {}
        
        if app.authenticate(@credentials)
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

    
    # Picnic::Authentication::Cas provides basic CAS (Central Authentication System) authentication 
    # for your Camping app.
    #
    # To learn more about CAS, see http://rubycas-client.googlecode.com and 
    # http://www.ja-sig.org/products/cas.
    # 
    # The module defines a <tt>service</tt> method that intercepts every request to check for CAS
    # authentication. If the user has already been authenticated, the request proceeds as normal
    # and the authenticated user's username is made available under <tt>@state[:cas_username]. 
    # Otherwise the request is redirected to your CAS server for authentication.
    # 
    # == Getting Started
    #
    # To activate CAS authentication for your application:
    #
    # 1. Picnic-fy your Camping app (e.g: <tt>Camping.goes :your_app; YourApp.picnic!</tt>)
    # 2. Call <tt>YourApp.authenticate_using :cas</tt>.
    # 3. In your app's configuration YAML file add something like this:
    #      authentication:
    #         cas_base_url: https://login.example.com/cas
    #    Where the value for </tt>cas_base_url</tt> is the URL of your CAS server.
    # 4. That's it. Now whenever a user tries to access any of your controller's actions,
    #    the request will be checked for CAS authentication. If the user is authenticated,
    #    their username is availabe in @state[:cas_username]. Note that there is currently
    #    no way to apply CAS authentication only to certain controllers or actions. When
    #    enabled, CAS authentication applies to your entire application, except for items
    #    placed in the /public subdirectory (CSS files, JavaScripts, images, etc.). The
    #    public directory does not require CAS authentication, so anyone can access its
    #    contents.
    #
    module Cas
      def self.include
        require 'camping/db'
        require 'camping/session'
      end
      
      $: << File.dirname(File.expand_path(__FILE__))+"/../../../rubycas-client2/lib" # for development
      require 'rubycas-client'
       
#       app = Kernel.const_get self.name.gsub(/^(\w+)::.+$/, '\1')
#       raise "Cannot enable CAS authentication because your Camping app does not extend Camping::Session." unless
#        app.ancestors.include?(Camping::Session)

      # There must be a smarter way to do this... but for now, we just re-implement
      # the Camping::Session method here to provide session support for CAS.
      module Session
        # This doesn't work :( MySQL connection is not carried over.
        #define_method(:service, Camping::Session.instance_method(:service))
        
        def service(*a)
          Camping::Models::Session.create_schema
          
          session = Camping::Models::Session.persist @cookies
          app = self.class.name.gsub(/^(\w+)::.+$/, '\1')
          @state = (session[app] ||= Camping::H[])
          hash_before = Marshal.dump(@state).hash
          s = super(*a)
          if session
            hash_after = Marshal.dump(@state).hash
            unless hash_before == hash_after
              session[app] = @state
              session.save
            end
          end
          s
        end
      end

      def self.included(mod)
        mod.module_eval do
          include Cas::Session
        end
      end

      def service(*a)
        $LOG.debug "Running CAS filter for request #{a.inspect}..."
        
        if @env['PATH_INFO'] =~ /^\/public\/.*/
          $LOG.debug "Access to items in /public subdirectory does not require CAS authentication."
          return super(*a)
        end
        if @state[:cas_username]
          $LOG.debug "Local CAS session exists for user #{@state[:cas_username]}."
          return super(*a)
        end
                
        client = CASClient::Client.new($CONF[:authentication].merge(:logger => $LOG))
        
        ticket = @input[:ticket]
        
        cas_login_url = client.add_service_to_login_url(read_service_url(@env))
        
        if ticket
          if ticket =~ /^PT-/
            st = CASClient::ProxyTicket.new(ticket, read_service_url(@env), @input[:renew])
          else
            st = CASClient::ServiceTicket.new(ticket, read_service_url(@env), @input[:renew])
          end
          
          $LOG.debug "Got CAS ticket: #{st.inspect}"
          
          client.validate_service_ticket(st)
          if st.is_valid?
            $LOG.info "CAS ticket #{st.ticket.inspect} is valid. Opening local CAS session for user #{st.response.user.inspect}."
            @state[:cas_username] = st.response.user
            return super(*a)
          else
            $LOG.warn "CAS ticket #{st.ticket.inspect} is INVALID. Redirecting back to CAS server at #{cas_login_url.inspect} for authentication."
            @state[:cas_username] = nil
            redirect cas_login_url
            s = self
          end
        else
          $LOG.info "User is unauthenticated and no CAS ticket found. Redirecting to CAS server at #{cas_login_url.inspect} for authentication."
          @state[:cas_username] = nil
          redirect cas_login_url
          s = self
        end
        s
      end
      
      private
      def read_service_url(env)
        if $CONF[:authentication][:service_url] 
          $CONF[:authentication][:service_url]
        else
          env['REQUEST_URI'].gsub(/service=[^&]*[&]?/,'').gsub(/ticket=[^&]*[&]?/,'')
        end
      end
    end
  end
end