# frozen_string_literal: true

require('gig')

ignore_files = %w(
  .gitignore
  Gemfile
  Rakefile.rb
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)
Gig.make_task(gemspec_filename: 'nonacat.gemspec', ignore_files: ignore_files)
