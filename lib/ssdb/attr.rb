module SSDB
  module Attr
    extend ActiveSupport::Concern

    included do
      instance_variable_set(:@ssdb_attr_names, [])

      after_commit :save_ssdb_attrs,  on: %i(create update)
      after_commit :clear_ssdb_attrs, on: :destroy
    end

    module ClassMethods
      attr_reader :ssdb_attr_names

      def ssdb_attr_id_field(id = nil)
        @ssdb_attr_id_field ||= (id || :id)
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

        @ssdb_attr_names << name.to_s

        define_method(name) do
          instance_variable_get("@#{name}") || begin
            val = SSDBAttr.pool.with { |conn| conn.get(ssdb_attr_key(name)) } || options[:default]
            instance_variable_set("@#{name}", val)
          end
          typecaster(instance_variable_get("@#{name}"), type)
        end

        define_method("#{name}=") do |val|
          send("#{name}_will_change!") unless typecaster(val, type) == send(name)
          instance_variable_set("@#{name}", val)
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
    def reload
      reload_ssdb_attrs if send(self.class.ssdb_attr_id_field)

      super
    end

    private

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

    #
    # Return the SSDB key for a attribute
    #
    # @param [String] name Attribute name.
    #
    # @return [String]
    #
    def ssdb_attr_key(name)
      "#{self.class.name.tableize}:#{send(self.class.ssdb_attr_id_field)}:#{name}"
    end

    #
    # Delete all SSDB Attributes of current object in the server.
    #
    #
    # @return [void]
    #
    def clear_ssdb_attrs
      SSDBAttr.pool.with do |conn|
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
      SSDBAttr.pool.with do |conn|
        (previous_changes.keys & self.class.ssdb_attr_names).each do |attr|
          conn.set("#{ssdb_attr_key(attr)}", previous_changes[attr][1])
        end
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
      SSDBAttr.pool.with do |conn|
        self.class.ssdb_attr_names.each do |attr|
          instance_variable_set("@#{attr}", conn.get(ssdb_attr_key(attr)))
        end
      end
    end
  end
end
