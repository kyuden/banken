require "test_helper"
require "rubygems"

class GemspecTest < Minitest::Test
  SPEC = Gem::Specification.load(File.expand_path("../banken.gemspec", __dir__))

  def test_packages_only_the_library_and_top_level_docs
    SPEC.files.each do |file|
      assert file.start_with?("lib/") || %w[README.md CHANGELOG.md LICENSE.txt].include?(file), "unexpected file in gem: #{file}"
    end
  end

  def test_packages_every_library_file_including_generator_templates_and_usage
    %w[
      lib/banken.rb
      lib/banken/railtie.rb
      lib/generators/banken/install/templates/application_loyalty.rb
      lib/generators/banken/install/USAGE
      lib/generators/banken/loyalty/templates/loyalty.rb
      lib/generators/banken/loyalty/USAGE
    ].each { |file| assert_includes SPEC.files, file }
  end

  def test_declares_the_supported_floors
    assert_equal Gem::Requirement.new(">= 3.3"), SPEC.required_ruby_version
    assert_equal Gem::Requirement.new(">= 7.1"), SPEC.runtime_dependencies.find { |d| d.name == "activesupport" }.requirement
  end

  def test_requires_mfa_and_links_the_changelog
    assert_equal "true", SPEC.metadata["rubygems_mfa_required"]
    assert_match %r{/CHANGELOG\.md\z}, SPEC.metadata["changelog_uri"]
  end
end
