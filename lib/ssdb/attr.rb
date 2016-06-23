module SSDB
  module Attr
    extend ActiveSupport::Concern

    included do
      instance_variable_set(:@ssdb_attr_names, [])

      after_destroy :clear_ssdb_attrs
    end

    module ClassMethods
      attr_reader :ssdb_attr_names

      def ssdb_attr_id_field(id = nil)
        @ssdb_attr_id_field ||= (id || :id)
      end

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

    def typecaster(val, type)
      case type.to_sym
      when :string  then val.to_s
      when :integer then val.to_i
      end
    end

    def ssdb_attr_key(name)
      "#{self.class.name.tableize}:#{send(self.class.ssdb_attr_id_field)}:#{name}"
    end

    def clear_ssdb_attrs
      SSDBAttr.pool.with do |conn|
        self.class.ssdb_attr_names.each { |attr| conn.del(ssdb_attr_key(attr)) }
      end
    end

    def save_ssdb_attrs
      SSDBAttr.pool.with do |conn|
        changed.each { |attr| conn.set("#{ssdb_attr_key(attr)}", send(attr)) }
      end

      changes_applied
    end

    def update_ssdb_attrs(attributes)
      attr_names = attributes.stringify_keys!.keys & self.class.ssdb_attr_names
      attr_names.each { |attr| send("#{attr}=", attributes[attr]) }

      save_ssdb_attrs
    end

    def reload_ssdb_attrs
      SSDBAttr.pool.with do |conn|
        self.class.ssdb_attr_names.each do |attr|
          instance_variable_set("@#{attr}", conn.get(ssdb_attr_key(attr)))
        end
      end

      clear_changes_information
    end
  end
end
