$LOAD_PATH.push File.expand_path("lib", __dir__)
require "knife-octo/version"

Gem::Specification.new do |s|
  s.name        = "knife-octo"
  s.version     = Knife::ChefInventory::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = "Vishal Basra"
  s.email       = "vishalbasra@live.com"
  s.homepage    = "https://github.com/vishalbasra/knife-octo"
  s.summary     = "Chef Knife plugin to help see stuff in Octopus Deploy"
  s.description = "A knife plugin to things much faster in Octopus Deploy server."
  s.date          = '2018-10-16'
  s.license     = "Apache License, v2.0"
  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  s.add_development_dependency "colorize",
end
