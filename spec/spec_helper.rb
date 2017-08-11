require "active_record"
require "nulldb"
require "ssdb-attr"

# Setup ActiveRecord
ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::VERSION::STRING >= "4.2"
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.before(:all) do
    # Connect to test SSDB server
    SSDBAttr.setup(:url => "redis://localhost:8888")

    # Clean up SSDB
    system('printf "7\nflushdb\n\n4\nping\n\n" | nc 127.0.0.1 8888 -i 1 > /dev/null')

    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute "DELETE FROM #{table}"
    end
  end
end

# Setup tables for test
tbls = [
  { "posts" => "updated_at DATETIME, saved_at DATETIME, changed_at DATETIME" },
  { "custom_id_fields" => "uuid VARCHAR" },
  { "custom_pool_names" => "uuid VARCHAR" }
]

tbls.each do |tbl|
  tbl.each do |tbl_name, sql|
    ActiveRecord::Base.connection.execute "CREATE TABLE #{tbl_name} (id INTEGER NOT NULL PRIMARY KEY, #{sql})"
  end
end

# ActiveRecord definition
class Post < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :name, :string
  ssdb_attr :int_version, :integer
  ssdb_attr :default_title, :string, default: "Untitled"
  ssdb_attr :title, :string
  ssdb_attr :content, :string
  ssdb_attr :version, :integer, default: 1
  ssdb_attr :default_version, :integer, :default => 100
  ssdb_attr :field_with_validation, :string

  validate :validate_field

  def validate_field
    if field_with_validation == "foobar"
      errors.add(:field_with_validation, "foobar error")
    end
  end
end

class CustomIdField < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr_id :uuid
  ssdb_attr :content, :string
end

class CustomPoolName < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr_pool :foo_pool

  ssdb_attr :foo_id, :integer
end
