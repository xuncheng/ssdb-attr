module SSDB
  module Attr
    extend ActiveSupport::Concern

    included do
      instance_variable_set(:@ssdb_attr_definition, {})

      after_create :save_ssdb_attrs
      after_update :save_ssdb_attrs
      after_commit :clear_ssdb_attrs, on: :destroy
    end

    module ClassMethods
      attr_reader :ssdb_attr_definition
      attr_reader :ssdb_attr_id_field
      attr_reader :ssdb_attr_pool_name

      #
      # 设置获取 SSDB Attr Id 的方式
      #
      # @param [String/Symbol] field_name
      #
      # @return [String]
      #
      def ssdb_attr_id(field_name)
        raise if field_name.nil?
        @ssdb_attr_id_field = field_name
      end

      #
      # Specify which SSDB ConnectionPool current class should use, by name specified in `SSDBAttr.setup`
      #
      # @param [String/Symbol] pool_name
      #
      # @return [String/Symbol]
      #
      def ssdb_attr_pool(pool_name)
        @ssdb_attr_pool_name = pool_name
      end

      def ssdb_attr_names
        @ssdb_attr_definition.keys
      end

      #
      # Method to define a SSDB attribute in a Ruby Class
      #
      # @param [String/Symbol] name Attribute name.
      # @param [String/Symbol] type Attribute type, now supports: string/integer
      # @param [options] options Extra options.
      #
      # @return [void]
      #
      def ssdb_attr(name, type, options = {})
        unless %i(string integer).include?(type)
          raise "Type not supported, only `:string` and `:integer` are supported now."
        end

        @ssdb_attr_definition[name.to_s] = type.to_s

        define_method(name) do
          instance_variable_get("@#{name}") || begin
            val = ssdb_attr_pool.with { |conn| conn.get(ssdb_attr_key(name)) } || options[:default]
            instance_variable_set("@#{name}", typecaster(val, type))
          end
        end

        define_method("#{name}=") do |val|
          send("#{name}_will_change!") unless typecaster(val, type) == send(name)
          instance_variable_set("@#{name}", val)
        end

        define_method("#{name}_default_value") do
          typecaster(options[:default], type)
        end

        define_method("#{name}_was")          { attribute_was(name) }

        define_method("#{name}_change")       { attribute_change(name) }

        define_method("#{name}_changed?")     { attribute_changed?(name) }

        define_method("restore_#{name}!")     { restore_attribute!(name) }

        define_method("#{name}_will_change!") { attribute_will_change!(name) }

      end
    end

    #
    # Overwrite `reload` method in ActiveRecord to reload SSDB attributes as well.
    #
    #
    # @return [void]
    #
    def reload(options = nil)
      super.tap do
        reload_ssdb_attrs
      end
    end

    #
    # Load the values of all specified attrs.
    #
    #
    # @return [void]
    #
    def load_ssdb_attrs(*fields)
      fields = (fields.map(&:to_s) & self.class.ssdb_attr_names)

      values = ssdb_attr_pool.with do |conn|
        conn.mget(fields.map { |name| ssdb_attr_key(name) })
      end

      fields.each_with_index do |attr, index|
        value = typecaster(values[index], self.class.ssdb_attr_definition[attr])
        instance_variable_set("@#{attr}", value)
      end
    end

    #
    # Return the SSDB key for a attribute
    #
    # @param [String] name Attribute name.
    #
    # @return [String]
    #
    def ssdb_attr_key(name)
      "#{self.class.name.tableize}:#{ssdb_attr_id}:#{name}"
    end

    #
    # Cast the value from SSDB to the correct type.
    #
    # @param [Any] val Any value taken from SSDB Server.
    # @param [String/Symbol] type Target value to cast to.
    #
    # @return [Any]
    #
    def typecaster(val, type)
      case type.to_sym
      when :string  then val.to_s
      when :integer then val.to_i
      else
        raise "Typecaster: i don't know this type: #{type}."
      end
    end

    private

    #
    # Return the ConnectionPool used by current Class.
    #
    #
    # @return [ConnectionPool]
    #
    def ssdb_attr_pool
      SSDBAttr.pool(self.class.ssdb_attr_pool_name)
    end

    def ssdb_attr_id
      send(self.class.ssdb_attr_id_field || :id)
    end

    #
    # Delete all SSDB Attributes of current object in the server.
    #
    #
    # @return [void]
    #
    def clear_ssdb_attrs
      ssdb_attr_pool.with do |conn|
        self.class.ssdb_attr_names.each { |attr| conn.del(ssdb_attr_key(attr)) }
      end
    end

    #
    # Save changed SSDb Attributes to the server.
    #
    #
    # @return [void]
    #
    def save_ssdb_attrs
      params = (changes.keys & self.class.ssdb_attr_names).map do |attr|
        ["#{ssdb_attr_key(attr)}", changes[attr][1]]
      end

      ssdb_attr_pool.with do |conn|
        conn.mset(*params.flatten)
      end if params.length > 0
    end

    #
    # Reload attribute values from the server.
    #
    # This method will overwrite current changed but not saved values in the object.
    #
    #
    # @return [void]
    #
    def reload_ssdb_attrs
      keys = self.class.ssdb_attr_names.map { |name| ssdb_attr_key(name) }
      values = ssdb_attr_pool.with { |conn| conn.mget(keys) }

      self.class.ssdb_attr_names.each_with_index do |attr, index|
        instance_variable_set("@#{attr}", typecaster(values[index], self.class.ssdb_attr_definition[attr]))
      end
    end
  end
end
