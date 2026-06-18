#!/usr/bin/env ruby
# Usage:
#   ruby Scripts/add-file-to-xcodeproj.rb <relative/path/File.swift> app
#   ruby Scripts/add-file-to-xcodeproj.rb <relative/path/FileTests.swift> test
#
# Adds a source file to the two app targets, or a test file to the test target.
# Groups are created/matched WITHOUT mutating any existing group's source tree
# (a previous version reset source trees and corrupted existing model paths).
require 'xcodeproj'

path = ARGV[0]
kind = ARGV[1] || 'app'
abort "usage: add-file-to-xcodeproj.rb <relative/path.swift> [app|test]" unless path

root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
project_path = File.join(root, 'PlayolaRadio.xcodeproj')
project = Xcodeproj::Project.open(project_path)

abs = File.join(root, path)
abort "file does not exist on disk: #{abs}" unless File.exist?(abs)

# Walk the directory segments from the project main group, matching existing
# groups by name and creating missing ones as group-relative children. Never
# call set_source_tree on a group we did not just create.
group = project.main_group
File.dirname(path).split('/').each do |segment|
  next if segment == '.'
  existing = group.children.find { |c| c.isa == 'PBXGroup' && c.display_name == segment }
  group = existing || group.new_group(segment, segment)
end

file_ref = group.files.find { |f| f.display_name == File.basename(path) }
file_ref ||= group.new_reference(abs)

# Defensive check: the reference must resolve to the real on-disk file.
unless File.expand_path(file_ref.real_path.to_s) == File.expand_path(abs)
  abort "refusing to save: #{File.basename(path)} resolves to #{file_ref.real_path} not #{abs}"
end

target_names = kind == 'test' ? ['PlayolaRadioTests'] : ['PlayolaRadio', 'PlayolaRadio Staging']
target_names.each do |name|
  target = project.targets.find { |t| t.name == name }
  raise "target #{name} not found" unless target
  already = target.source_build_phase.files.any? { |bf| bf.file_ref == file_ref }
  target.add_file_references([file_ref]) unless already
end

project.save
puts "registered #{path} -> #{target_names.join(', ')}"
