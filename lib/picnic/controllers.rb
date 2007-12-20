module Picnic
  module Controllers
    # Provides a controller for serving up static content from your app's <tt>/public</tt> directory.
    # This can be used to serve css, js, jpg, png, and gif files. Anything you put in your app's
    # '/public' directory will be served up under the '/public' path.
    #
    # That is, say you have:
    #   /srv/www/camping/my_app/public/test.jpg
    # This should be availabe at:
    #   http://myapp.com/public/test.jpg
    #
    # This controller is automatically enabled for all Picnic-enabled apps. 
    class Public < Camping::Controllers::R '/public/(.+)'
      BASE_PATH = ("#{$APP_PATH}/.." || File.expand_path(File.dirname(__FILE__)))+'/lib/public'
      
      MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript', 
                    '.jpg' => 'image/jpeg', '.png' => 'image/png', 
                    '.gif' => 'image/gif'}
  
      def get(path)
        @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
        unless path.include? ".." # prevent directory traversal attacks
          @headers['X-Sendfile'] = "#{BASE_PATH}/#{path}"
        else
          @status = "403"
          "403 - Invalid path"
        end
      end
    end
  end
end