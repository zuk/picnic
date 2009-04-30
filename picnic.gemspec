# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{picnic}
  s.version = '0.8.0.' + Time.now.strftime('%Y%m%d')

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matt Zukowski"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = %q{Camping for sissies}
  s.email = %q{matt@roughest.net}
  s.extra_rdoc_files = ["CHANGELOG.txt", "History.txt", "LICENSE.txt", "Manifest.txt", "README.txt"]
  s.files = ["CHANGELOG.txt", "History.txt", "LICENSE.txt", "Manifest.txt", "README.txt", "Rakefile", "lib/picnic.rb", "lib/picnic/authentication.rb", "lib/picnic/cli.rb", "lib/picnic/conf.rb", "lib/picnic/controllers.rb", "lib/picnic/logger.rb", "lib/picnic/server.rb", "lib/picnic/service_control.rb", "lib/picnic/version.rb", "setup.rb", "test/picnic_test.rb", "test/test_helper.rb", "vendor/zuk-camping-2.0.20090429/CHANGELOG", "vendor/zuk-camping-2.0.20090429/COPYING", "vendor/zuk-camping-2.0.20090429/README", "vendor/zuk-camping-2.0.20090429/Rakefile", "vendor/zuk-camping-2.0.20090429/bin/camping", "vendor/zuk-camping-2.0.20090429/doc/camping.1.gz", "vendor/zuk-camping-2.0.20090429/examples/README", "vendor/zuk-camping-2.0.20090429/examples/blog.rb", "vendor/zuk-camping-2.0.20090429/examples/campsh.rb", "vendor/zuk-camping-2.0.20090429/examples/tepee.rb", "vendor/zuk-camping-2.0.20090429/extras/Camping.gif", "vendor/zuk-camping-2.0.20090429/extras/permalink.gif", "vendor/zuk-camping-2.0.20090429/lib/camping-unabridged.rb", "vendor/zuk-camping-2.0.20090429/lib/camping.rb", "vendor/zuk-camping-2.0.20090429/lib/camping/ar.rb", "vendor/zuk-camping-2.0.20090429/lib/camping/ar/session.rb", "vendor/zuk-camping-2.0.20090429/lib/camping/mab.rb", "vendor/zuk-camping-2.0.20090429/lib/camping/reloader.rb", "vendor/zuk-camping-2.0.20090429/lib/camping/server.rb", "vendor/zuk-camping-2.0.20090429/lib/camping/session.rb", "vendor/zuk-camping-2.0.20090429/setup.rb", "vendor/zuk-camping-2.0.20090429/test/apps/env_debug.rb", "vendor/zuk-camping-2.0.20090429/test/apps/forms.rb", "vendor/zuk-camping-2.0.20090429/test/apps/misc.rb", "vendor/zuk-camping-2.0.20090429/test/apps/sessions.rb", "vendor/zuk-camping-2.0.20090429/test/test_camping.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://picnic.rubyforge.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{picnic}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Camping for sissies}
  s.test_files = ["test/picnic_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 0"])
      s.add_runtime_dependency(%q<markaby>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
      s.add_development_dependency(%q<hoe>, [">= 1.8.2"])
    else
      s.add_dependency(%q<rack>, [">= 0"])
      s.add_dependency(%q<markaby>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 0"])
      s.add_dependency(%q<hoe>, [">= 1.8.2"])
    end
  else
    s.add_dependency(%q<rack>, [">= 0"])
    s.add_dependency(%q<markaby>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 0"])
    s.add_dependency(%q<hoe>, [">= 1.8.2"])
  end
end
