require 'active_record'
require 'nulldb'
require 'ssdb-attr'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/mock'
require 'minitest/pride'

SSDBAttr.setup url: 'redis://localhost:6379/15'

# Setup activerecord
ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::VERSION::STRING >= '4.2'

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', database: ':memory:'

ActiveRecord::Base.connection.execute "CREATE TABLE posts (id INTEGER NOT NULL PRIMARY KEY, updated_at DATETIME, content_updated_at DATETIME, title_updated_at DATETIME)"
