require "redis"
require "connection_pool"
require "active_support/concern"
require "active_support/inflector"
require "ssdb-attr/version"
require "ssdb/attr"

module SSDBAttr
  class << self
    attr_accessor :pool

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
    # @param [Hash] options
    #
    # @return [void]
    #
    def setup(options={})
      pool_size = (options[:pool]     || 1).to_i
      timeout   = (options[:timeout]  || 2).to_i

      SSDBAttr.pool = ConnectionPool.new(size: pool_size, timeout: timeout) do
        if options[:url].present?
          Redis.new(url: options[:url])
        else
          Redis.new(host: options[:host], port: options[:port])
        end
      end
    end
  end
end
