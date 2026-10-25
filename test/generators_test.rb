require "test_helper"
require "tmpdir"
require "fileutils"

require "rails/generators"
require "generators/banken/install/install_generator"
require "generators/banken/loyalty/loyalty_generator"

class GeneratorsTest < Minitest::Test
  TEMPLATE_DIR = File.expand_path("../lib/generators/banken", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir("banken-generators")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # banken:install

  def test_install_generator_creates_application_loyalty_from_the_template
    generate(Banken::Generators::InstallGenerator, [])

    assert_equal File.read("#{TEMPLATE_DIR}/install/templates/application_loyalty.rb"),
                 File.read("#{@tmpdir}/app/loyalties/application_loyalty.rb")
  end

  def test_generated_application_loyalty_denies_everything_by_default
    generate(Banken::Generators::InstallGenerator, [])
    loyalty_class = load_generated_class("app/loyalties/application_loyalty.rb", :ApplicationLoyalty)
    loyalty = loyalty_class.new(:user, :record)

    %w[index? show? create? new? update? edit? destroy?].each do |query|
      assert_equal false, loyalty.public_send(query), "#{query} should be denied by default"
    end
  end

  def test_generated_application_loyalty_exposes_user_and_record
    generate(Banken::Generators::InstallGenerator, [])
    loyalty_class = load_generated_class("app/loyalties/application_loyalty.rb", :ApplicationLoyalty)
    loyalty = loyalty_class.new(:user, :record)

    assert_equal :user, loyalty.user
    assert_equal :record, loyalty.record
  end

  def test_generated_application_loyalty_delegates_new_to_create_and_edit_to_update
    generate(Banken::Generators::InstallGenerator, [])
    loyalty_class = load_generated_class("app/loyalties/application_loyalty.rb", :ApplicationLoyalty)
    permissive = Class.new(loyalty_class) do
      def create?; true; end
      def update?; true; end
    end
    loyalty = permissive.new(:user, :record)

    assert_equal true, loyalty.new?
    assert_equal true, loyalty.edit?
  end

  def test_test_support_application_loyalty_stays_in_sync_with_the_template
    assert_equal File.read("#{TEMPLATE_DIR}/install/templates/application_loyalty.rb"),
                 File.read(File.expand_path("support/loyalties/application_loyalty.rb", __dir__))
  end

  # banken:loyalty

  def test_loyalty_generator_prints_no_error_with_the_default_test_framework
    # Rails apps default to test_framework :test_unit. Banken ships no test
    # generator, so the generator must not try to invoke one.
    out, err = capture_io { Dir.chdir(@tmpdir) { Banken::Generators::LoyaltyGenerator.new(%w[posts], { test_framework: :test_unit }).invoke_all } }

    refute_match(/error|not found/i, out + err)
    assert_match(/create\s+app\/loyalties\/posts_loyalty\.rb/, out)
  end

  def test_loyalty_generator_does_not_expose_a_test_framework_option
    refute_includes Banken::Generators::LoyaltyGenerator.class_options.keys, :test_framework
  end

  def test_loyalty_generator_creates_a_loyalty_inheriting_from_application_loyalty
    generate(Banken::Generators::LoyaltyGenerator, %w[posts])

    assert_equal "class PostsLoyalty < ApplicationLoyalty\nend\n",
                 File.read("#{@tmpdir}/app/loyalties/posts_loyalty.rb")
  end

  def test_loyalty_generator_camelizes_multiword_names
    generate(Banken::Generators::LoyaltyGenerator, %w[blog_posts])

    assert_match(/\Aclass BlogPostsLoyalty < ApplicationLoyalty/, File.read("#{@tmpdir}/app/loyalties/blog_posts_loyalty.rb"))
  end

  def test_loyalty_generator_places_namespaced_loyalties_in_subdirectories
    generate(Banken::Generators::LoyaltyGenerator, %w[admin/posts])

    assert_match(/class Admin::PostsLoyalty < ApplicationLoyalty/, File.read("#{@tmpdir}/app/loyalties/admin/posts_loyalty.rb"))
  end

  def test_generated_loyalty_inherits_the_generated_application_loyalty_defaults
    generate(Banken::Generators::InstallGenerator, [])
    generate(Banken::Generators::LoyaltyGenerator, %w[widgets])
    namespace = Module.new
    load_into(namespace, "app/loyalties/application_loyalty.rb")
    load_into(namespace, "app/loyalties/widgets_loyalty.rb")

    assert_operator namespace::WidgetsLoyalty, :<, namespace::ApplicationLoyalty
    assert_equal false, namespace::WidgetsLoyalty.new(:user, :record).index?
  end

  private

    # quiet: true suppresses say_status output, so assertions about the
    # generator output must invoke the generator directly instead.
    def generate(generator, args)
      Dir.chdir(@tmpdir) { generator.new(args, { quiet: true }).invoke_all }
    end

    def load_generated_class(relative_path, const_name)
      namespace = Module.new
      load_into(namespace, relative_path)
      namespace.const_get(const_name)
    end

    def load_into(namespace, relative_path)
      path = File.join(@tmpdir, relative_path)
      namespace.module_eval(File.read(path), path)
    end
end
