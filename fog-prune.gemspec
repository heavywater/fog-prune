$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'fog-prune/version'
Gem::Specification.new do |s|
  s.name = 'fog-prune'
  s.version = FogPrune::VERSION.version
  s.summary = 'Chef pruning with fog integration'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/heavywater/fog-prune'
  s.description = 'Chef pruner'
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.executables << 'fog-prune'
  s.add_dependency 'chef'
  s.add_dependency 'fog', '~> 1.20'
  s.files = Dir['**/*']
end
