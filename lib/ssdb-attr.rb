require "redis"
require "connection_pool"
require 'active_support'
require "active_support/core_ext"
require "active_support/concern"
require "active_support/inflector"
require "ssdb-attr/version"
require "ssdb/attr"

module SSDBAttr
  class << self
    attr_accessor :pools
    attr_accessor :default_pool_name

    #
    # Globally setup SSDBAttr
    #
    # This method will setup the connecton pool to SSDB server.
    #
    # You should pass following values in `options` hash:
    #
    # `url/host+port`: To locate the SSDB server, `url` takes precedence.
    # `pool`: Pool size of the connection pool. Default to 1.
    # `timeout`: Timeout of the connection pool, in second, Default to 2.
    #
    #  Examples:
    #
    # `SSDBAttr.setup({ :url => "redis://localhost:8888" })`: will setup a single pool to the SSDB instance `url` points to.
    # `SSDBAttr.setup({ :url => "redis://localhost:8888", :name => :main })`: will setup a named single pool.
    # `SSDBAttr.setup([ { :url => "redis://localhost:8888", :name => :pool1 }, { :url => "redis://localhost:6379", :name => :pool2 } ])`: will setup two named pools.
    #
    #
    # @param [Hash] options
    #
    # @return [void]
    #
    def setup(configuration)
      raise "SSDB-Attr could not initialize!" if configuration.nil?

      SSDBAttr.pools = {}

      if configuration.is_a?(Hash)
        # Only one and the default connection pool.
        conf = configuration.symbolize_keys

        pool_name = conf[:name] || :default

        SSDBAttr.pools[pool_name.to_sym] = create_pool(configuration)
        SSDBAttr.default_pool_name = pool_name
      end

      if configuration.is_a?(Array)
        # Multiple connection pools
        configuration.each do |c|
          conf = c.symbolize_keys

          pool_name = conf[:name]

          raise "ssdb-attr: Pool name not specified!" if pool_name.blank?

          SSDBAttr.pools[pool_name.to_sym] = create_pool(conf)
          SSDBAttr.default_pool_name = pool_name if conf[:default]
        end
      end

      raise "ssdb-attr: No default pool in configuration!" if SSDBAttr.pool.nil?
    end

    def pool(name=nil)
      name = name || SSDBAttr.default_pool_name
      SSDBAttr.pools[name.to_sym]
    end

    def default_pool
      SSDBAttr.pools[SSDBAttr.default_pool_name]
    end

    def create_pool(pool_options)
      defaults = { :pool_size => 1, :timeout => 1 }

      options = pool_options.reverse_merge(defaults).deep_symbolize_keys

      ConnectionPool.new(:size => options[:pool_size], :timeout => options[:timeout]) do
        create_conn(options)
      end
    end

    def create_conn(conn_options)
      if !conn_options[:url].nil?
        Redis.new(:url => conn_options[:url])
      else
        Redis.new(:host => conn_options[:host], :port => conn_options[:port])
      end
    end

    #
    # 获取多个 AR 对象的多个 SSDB 字段
    #
    # 例如:
    #
    # notes = Note.where("<some where>").limit(15)
    # SSDBAttr.load_attrs(notes, :public_title, :public_content)
    #
    # @param [Array] objects
    # @param [Array] fields
    #
    # @return [ActiveRecord::Relation|Array]
    #
    def load_attrs(objects, *fields)
      fields.map!(&:to_s)

      keys = objects.flat_map do |object|
        fields.map { |name| object.ssdb_attr_key(name) }
      end
      values = SSDBAttr.pool.with { |conn| conn.mget(keys) }
      key_values = keys.zip(values).to_h

      objects.each do |object|
        fields.each do |name|
          next unless object.class.ssdb_attr_names.include?(name.to_s)

          value =
            if (raw_value = key_values[object.ssdb_attr_key(name)]).present?
              object.typecaster(raw_value, object.class.ssdb_attr_definition[name])
            else
              object.public_send("#{name}_default_value")
            end

          object.instance_variable_set("@#{name}", value)
        end
      end

      objects
    end
  end
end
