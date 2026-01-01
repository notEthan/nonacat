# frozen_string_literal: true

require('rake/testtask')
Rake::TestTask.new do |test_task|
  test_task.pattern = "test/*_test.rb"
end

task 'default' => 'test'

require('gig')

ignore_files = %w(
  .gitignore
  Gemfile
  Rakefile.rb
  test/**/*
).map { |glob| Dir.glob(glob, File::FNM_DOTMATCH) }.inject([], &:|)
Gig.make_task(gemspec_filename: 'nonacat.gemspec', ignore_files: ignore_files)
