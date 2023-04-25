# frozen_string_literal: true

require_relative "lib/nonacat/version"

Gem::Specification.new do |spec|
  spec.name = "nonacat"
  spec.version = Nonacat::VERSION
  spec.authors = ["Ethan"]
  spec.email = ["ethan@unth.net"]

  spec.summary = "TODO: Write a short summary, because RubyGems requires one."
  spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.license = "MIT"

  spec.files = [
  ].reject { |f| File.lstat(f).ftype == 'directory' }
  spec.require_paths = ["lib"]
end
