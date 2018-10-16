$LOAD_PATH.push File.expand_path("lib", __dir__)
require "knife-octo/version"
Gem::Specification.new do |s|
  s.name        = "knife-octo"
  s.version     = Knife::Octo::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = "Vishal Basra"
  s.email       = "vishalbasra@live.com"
  s.homepage    = "https://github.com/vishalbasra/knife-octo"
  s.summary     = "Chef Knife plugin to help see stuff in Octopus Deploy"
  s.description = "A knife plugin to things much faster in Octopus Deploy server."
  s.date          = '2018-10-16'
  s.license     = "Apache-2.0"
  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  s.add_dependency "chef", "~> 12.11"
  s.add_dependency "colorize", "~> 0.7.7"
  s.add_development_dependency "colorize", "~> 0.7.7"
  s.add_development_dependency "chef", "~> 12.11"
end
