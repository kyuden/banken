require 'rubygems'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

desc "Run all tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
end

task :default => [:test]
