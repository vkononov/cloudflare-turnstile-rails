require 'bundler/gem_tasks'
require 'minitest/test_task'

Minitest::TestTask.create

require 'rubocop/rake_task'

RuboCop::RakeTask.new

desc 'Run JavaScript unit tests for the asset-pipeline helper (vitest).'
task :js_test do
  abort('npm not found on PATH') unless system('command -v npm > /dev/null')
  sh 'npm test'
end

task default: %i[test js_test rubocop]
