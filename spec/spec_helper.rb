require 'active_record'
require 'nulldb'
require 'ssdb-attr'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/mock'
require 'minitest/pride'

SSDBAttr.setup url: 'http://localhost:8888'

ActiveRecord::Base.establish_connection :adapter => :nulldb
