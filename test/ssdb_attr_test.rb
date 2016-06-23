require 'ssdb-attr'
require 'active_record'
ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::VERSION::STRING >= '4.2'

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
test_framework = defined?(MiniTest::Test) ? MiniTest::Test : MiniTest::Unit::TestCase

require File.expand_path(File.dirname(__FILE__) + "/../lib/ssdb/attr")

def connect!
  SSDBAttr.setup(url: 'redis://localhost:6379/15')
  ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'
end

def setup!
  connect!
  { 'posts' => 'updated_at DATETIME, saved_at DATETIME, changed_at DATETIME' }.each do |table_name, columns_as_sql_string|
    ActiveRecord::Base.connection.execute "CREATE TABLE #{table_name} (id INTEGER NOT NULL PRIMARY KEY, #{columns_as_sql_string})"
  end

  { 'custom_id_fields' => 'uuid VARCHAR' }.each do |table_name, columns_as_sql_string|
    ActiveRecord::Base.connection.execute "CREATE TABLE #{table_name} (id INTEGER NOT NULL PRIMARY KEY, #{columns_as_sql_string})"
  end
end

setup!

class Post < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :name, :string
  ssdb_attr :int_version, :integer
  ssdb_attr :default_title, :string, default: "Untitled"
  ssdb_attr :title, :string
  ssdb_attr :content, :string
  ssdb_attr :version, :integer, default: 1

  # before_update_ssdb_attrs :before1, :before2
  # after_update_ssdb_attrs :after1, :after2

  def callback_out
    @callback_out ||= []
  end

  [:before1, :before2, :after1, :after2].each do |name|
    define_method(name) do
      callback_out << name
    end
  end
end

class CustomIdField < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :content, :string
  ssdb_attr_id_field :uuid
end

class SsdbAttrTest < test_framework
  def setup
    SSDBAttr.pool.with { |conn| conn.flushdb }
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute "DELETE FROM #{table}"
    end
    @post = Post.create(updated_at: 1.day.ago, saved_at: 1.day.ago, changed_at: 1.day.ago)
    @custom_id_field = CustomIdField.create(uuid: 123)
  end

  def test_respond_to_methods
    assert_equal true, @post.respond_to?(:name)
    assert_equal true, @post.respond_to?(:name=)
    assert_equal true, @post.respond_to?(:name_was)
    assert_equal true, @post.respond_to?(:name_change)
    assert_equal true, @post.respond_to?(:name_changed?)
    assert_equal true, @post.respond_to?(:restore_name!)
    assert_equal true, @post.respond_to?(:name_will_change!)
  end

  def test_integer_attribute
    assert_equal 0, @post.int_version
    @post.int_version = "4"
    assert_equal 4, @post.int_version
  end

  def test_with_default_value
    assert_equal "Untitled", @post.default_title
  end

  def test_ssdb_attr_key
    assert_equal "posts:#{@post.id}:name", @post.ssdb_attr_key("name")
  end

  def test_custom_ssdb_attr_id_field
    assert_equal :uuid, CustomIdField.ssdb_attr_id_field
    assert_equal "custom_id_fields:123:content", @custom_id_field.ssdb_attr_key("content")
  end

  def test_update_ssdb_attrs_with_symbolize_keys
    @post.update_ssdb_attrs(title: "note one", content: "testing!!!", version: 1)
    @post.reload_ssdb_attrs
    assert_equal "note one", @post.title
    assert_equal "testing!!!", @post.content
    assert_equal 1, @post.version
  end

  def test_update_ssdb_attrs_with_string_keys
    @post.update_ssdb_attrs("title" => "note one", "content" => "testing!!!", "version" => 1)
    @post.reload_ssdb_attrs
    assert_equal "note one", @post.title
    assert_equal "testing!!!", @post.content
    assert_equal 1, @post.version
  end

  # def test_update_ssdb_attrs_on_object_return_true
  #   assert_equal true, @post.update_ssdb_attrs(title: "note one", content: "testing!!!", version: 1)
  # end

  # def test_update_ssdb_attrs_callbacks
  #   @post.update_ssdb_attrs(title: "something")
  #   assert_equal [:before1, :before2, :after1, :after2], @post.callback_out
  # end

  def test_object_destroy_callbacks
    @post.update_ssdb_attrs(title: "note one", content: "nice job!")
    ssdb_title_key = @post.ssdb_attr_key(:title)
    ssdb_content_key = @post.ssdb_attr_key(:content)
    assert_equal true, SSDBAttr.pool.with { |conn| conn.exists(ssdb_title_key) }
    assert_equal true, SSDBAttr.pool.with { |conn| conn.exists(ssdb_content_key) }
    @post.destroy
    assert_equal false, SSDBAttr.pool.with { |conn| conn.exists(ssdb_title_key) }
    assert_equal false, SSDBAttr.pool.with { |conn| conn.exists(ssdb_content_key) }
  end

  # def test_object_create_callbacks
  #   title_key = @post.ssdb_attr_key(:title)
  #   default_title_key = @post.ssdb_attr_key(:default_title)
  #   version_key = @post.ssdb_attr_key(:version)

  #   assert_equal 10, SSDBAttr.pool.with { |conn| conn.keys.count }
  #   assert_equal true, SSDBAttr.pool.with { |conn| conn.exists(title_key) }
  #   assert_equal "Untitled", SSDBAttr.pool.with { |conn| conn.get(default_title_key) }
  #   assert_equal "1", SSDBAttr.pool.with { |conn| conn.get(version_key) }
  # end
end
