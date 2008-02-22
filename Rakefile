require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/contrib/rubyforgepublisher'
require 'fileutils'
require 'hoe'
include FileUtils
require File.join(File.dirname(__FILE__), 'lib', 'picnic', 'version')

AUTHOR = "Matt Zukowski"
EMAIL = "matt@roughest.net"
DESCRIPTION = "Camping for sissies"
GEM_NAME = "picnic"
RUBYFORGE_PROJECT = "picnic"
HOMEPATH = "http://#{RUBYFORGE_PROJECT}.rubyforge.org"


NAME = "picnic"
#REV = nil
REV = `svn info`[/Revision: (\d+)/, 1] rescue nil
VERS = ENV['VERSION'] || (Picnic::VERSION::STRING + (REV ? ".#{REV}" : ""))
                          CLEAN.include ['**/.*.sw?', '*.gem', '.config']
RDOC_OPTS = ['--quiet', '--title', "picnic #{VERS} documentation",
    "--opname", "index.html",
    "--line-numbers", 
    "--main", "README",
    "--inline-source"]

class Hoe
  def extra_deps
    @extra_deps.reject { |x| Array(x).first == 'hoe' } 
  end 
end

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
hoe = Hoe.new(GEM_NAME, VERS) do |p|
  p.author = AUTHOR 
  p.description = DESCRIPTION
  p.email = EMAIL
  p.summary = DESCRIPTION
  p.url = HOMEPATH
  p.rubyforge_name = RUBYFORGE_PROJECT if RUBYFORGE_PROJECT
  p.test_globs = ["test/**/*_test.rb"]
  p.clean_globs = CLEAN  #An array of file patterns to delete on clean.
  
  # == Optional
  #p.changes        - A description of the release's latest changes.
  #p.extra_deps     - An array of rubygem dependencies.
  #p.spec_extras    - A hash of extra values to set in the gemspec.
  
  # note that camping-1.5.0.180 is now bundled with picnic the vendor directory, 
  p.extra_deps = ['markaby']
end
