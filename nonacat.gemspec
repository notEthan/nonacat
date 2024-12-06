# frozen_string_literal: true

require_relative "lib/nonacat/version"

Gem::Specification.new do |spec|
  spec.name = "nonacat"
  spec.version = Nonacat::VERSION
  spec.authors = ["Ethan"]
  spec.email = ["ethan@unth.net"]

  spec.summary = "A Github API client - unofficial, unaffiliated"
  spec.description = "Nonacat builds from Github's OpenAPI description using the gem `scorpio` to offer an alternative client to Github's REST API."
  spec.homepage = "https://github.com/notEthan/nonacat"
  spec.license = "MIT"

  spec.files = [
    'LICENSE.txt',
    'README.md',
    'nonacat.gemspec',
    *Dir['lib/**/*'],
    'github-rest-api-description/LICENSE.md',
    'github-rest-api-description/api.github.com.json.zz',
    'github-rest-api-description/updated.yml',
  ].reject { |f| File.lstat(f).ftype == 'directory' }

  spec.require_paths = ["lib"]
  spec.bindir        = 'bin'
  spec.executables   = ['nonacat_update']

  spec.add_dependency('scorpio', '~> 0.7')
end
