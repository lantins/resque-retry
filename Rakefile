require 'rake/testtask'
require 'fileutils'
require 'yard'
require 'yard/rake/yardoc_task'

task :default => :test

##
# Test task.
Rake::TestTask.new(:test) do |task|
  task.libs << 'lib' << 'test'
  task.test_files = FileList['test/*_test.rb']
  task.verbose = true
end