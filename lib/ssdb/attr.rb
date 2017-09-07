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

        @ssdb_attr_definition[name.to_sym] = options.symbolize_keys.merge(:type => type.to_sym)

        define_method(name) do
          return instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")

          val = ssdb_attr_pool.with { |conn| conn.get(ssdb_attr_key(name)) } || options[:default]
          if val.nil?
            instance_variable_set("@#{name}", nil)
          else
            instance_variable_set("@#{name}", typecaster(val, type))
          end
        end

        define_method("#{name}=") do |val|
          send("#{name}_will_change!") unless typecaster(val, type) == send(name)
          instance_variable_set("@#{name}", val)
        end

        define_method("#{name}_default_value") do
          return nil unless options.key?(:default)
          typecaster(options[:default], type)
        end

        define_method("#{name}_was")          { attribute_was(name) }

        define_method("#{name}_change")       { attribute_change(name) }

        define_method("#{name}_changed?")     { attribute_changed?(name) }

        define_method("restore_#{name}!")     { restore_attribute!(name) }

        define_method("#{name}_will_change!") { attribute_will_change!(name) }

      end
    end

    # 返回某个 SSDB Attr 的类型
    #
    # @param [String] name
    #
    # @return [Symbol]
    #
    def ssdb_attr_type(name)
      self.class.ssdb_attr_definition.dig(name.to_sym, :type)
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
      fields = (fields.map(&:to_sym) & self.class.ssdb_attr_names)

      values = ssdb_attr_pool.with do |conn|
        conn.mget(fields.map { |name| ssdb_attr_key(name) })
      end

      fields.each_with_index do |attr, index|
        if (raw_value = values[index]).nil?
          instance_variable_set("@#{attr}", nil)
        else
          value = typecaster(raw_value, ssdb_attr_type(attr))
          instance_variable_set("@#{attr}", value)
        end
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
      changed_ssdb_attributes = changes.keys.map(&:to_sym) & self.class.ssdb_attr_names

      will_removed_attributes = []
      will_updated_attributes = []

      changed_ssdb_attributes.each do |attr|
        if (new_value = changes[attr][1]).nil?
          will_removed_attributes << "#{ssdb_attr_key(attr)}"
        else
          will_updated_attributes << ["#{ssdb_attr_key(attr)}", new_value]
        end
      end

      unless will_updated_attributes.empty?
        ssdb_attr_pool.with { |conn| conn.mset(*will_updated_attributes.flatten) }
      end

      unless will_removed_attributes.empty?
        ssdb_attr_pool.with { |conn| conn.del(*will_removed_attributes) }
      end
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
      load_ssdb_attrs(*self.class.ssdb_attr_names)
    end
  end
end
