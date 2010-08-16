require "rake/testtask"
require "lib/rake_commit_task"

Rake::TestTask.new do |t|
  t.pattern = "test/**/*_test.rb"
end

RakeCommitTask.new("commit") do |t|
  t.test_task = :test
  t.prompt_for :message
end

task :default => :commit