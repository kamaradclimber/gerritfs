# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gerritfs/version'

Gem::Specification.new do |spec|
  spec.name          = "gerritfs"
  spec.version       = Gerritfs::VERSION
  spec.authors       = ["Grégoire Seux"]
  spec.email         = "grego_gerritfs@familleseux.net"

  spec.summary       = %q{Expose gerrit reviews as a file system}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/kamaradclimber/gerritfs"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rubocop"

  spec.add_dependency "httpclient"
  spec.add_dependency "rfusefs"
  spec.add_dependency "mash"
end
