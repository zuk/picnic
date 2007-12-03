module Picnic
  module Controllers
    class Public < Camping::Controllers::R '/public/(.+)'
      BASE_PATH = File.expand_path(File.dirname(__FILE__))+'/lib/public'
      
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