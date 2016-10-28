require 'active_record'
require 'nulldb'
require 'ssdb-attr'

SSDBAttr.setup(url: 'redis://localhost:6379/15')

# Setup ActiveRecord
ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::VERSION::STRING >= '4.2'
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

# Setup tables for test
tbls = [
  { 'posts' => 'updated_at DATETIME, saved_at DATETIME, changed_at DATETIME' },
  { 'custom_id_fields' => 'uuid VARCHAR' }
]

tbls.each do |tbl|
  tbl.each do |tbl_name, sql|
    ActiveRecord::Base.connection.execute "CREATE TABLE #{tbl_name} (id INTEGER NOT NULL PRIMARY KEY, #{sql})"
  end
end
