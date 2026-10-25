require "test_helper"
require "rails"
require "banken/railtie"

class RailtieTest < Minitest::Test
  FakeApp = Struct.new(:deprecators)

  def test_railtie_is_a_rails_railtie
    assert_operator Banken::Railtie, :<, Rails::Railtie
  end

  def test_railtie_registers_the_deprecator_with_the_application
    initializer = Banken::Railtie.initializers.find { |i| i.name == "banken.deprecator" }
    refute_nil initializer, "expected a banken.deprecator initializer"

    app = FakeApp.new({})
    initializer.block.call(app)

    assert_same Banken.deprecator, app.deprecators[:banken]
  end
end

class RailtieAutoloadTest < Minitest::Test
  # The conditional `require "banken/railtie" if defined?(::Rails::Railtie)` in
  # lib/banken.rb can only be observed in a fresh process, because the test
  # suite itself requires banken before rails.
  def test_requiring_banken_after_rails_loads_the_railtie
    assert_equal "defined", run_in_fresh_process('require "rails"; require "banken"; puts defined?(Banken::Railtie) ? "defined" : "missing"')
  end

  def test_requiring_banken_without_rails_does_not_load_the_railtie
    assert_equal "missing", run_in_fresh_process('require "banken"; puts defined?(Banken::Railtie) ? "defined" : "missing"')
  end

  private

    def run_in_fresh_process(code)
      lib = File.expand_path("../../lib", __dir__)
      output = IO.popen([RbConfig.ruby, "-I", lib, "-e", code], err: [:child, :out], &:read)
      assert $?.success?, "child process failed:\n#{output}"
      output.lines.last.to_s.strip
    end
end
