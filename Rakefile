$LOAD_PATH.unshift 'lib'

require 'rake/testtask'
require 'fileutils'
require 'yard'
require 'yard/rake/yardoc_task'

task :default => :test

##
# Test task.
Rake::TestTask.new(:test) do |task|
  task.test_files = FileList['test/*_test.rb']
  task.verbose = true
end

##
# docs task.
YARD::Rake::YardocTask.new :yardoc do |t|
    t.files   = ['lib/**/*.rb']
    t.options = ['--output-dir', 'doc/',
                 '--files', 'LICENSE',
                 '--readme', 'README.md',
                 '--title', 'resque-retry documentation']
end