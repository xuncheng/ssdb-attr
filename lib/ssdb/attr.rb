module SSDB
  module Attr
    extend ActiveSupport::Concern

    included do
      define_model_callbacks :update_ssdb_attrs, only: [:before, :after]
      after_create :init_ssdb_attrs
      after_destroy :clear_ssdb_attrs
    end

    def update_ssdb_attrs(attributes)
      # Determine what attrs are requested to be updated
      attributes = attributes.symbolize_keys
      attr_names = attributes.keys & self.class.ssdb_attr_names

      # Determine dirty fields
      attr_names.each do |name|
        send("#{name}_will_change!") unless attributes[name] == send(name)
      end

      run_callbacks :update_ssdb_attrs do
        SSDBAttr.pool.with do |conn|
          attr_names.each { |name| send("#{name}=", attributes[name]) }
        end
      end

      # Clear dirty fields
      clear_attribute_changes(attr_names)

      true # always return true
    end

    def init_ssdb_attrs
      self.class.ssdb_attr_names.each do |attribute|
        SSDBAttr.pool.with { |conn| conn.set(to_ssdb_attr_key(attribute), self.send(attribute)) }
      end
    end

    def clear_ssdb_attrs
      self.class.ssdb_attr_names.each do |attribute|
        SSDBAttr.pool.with { |conn| conn.del(to_ssdb_attr_key(attribute)) }
      end
    end

    def to_ssdb_attr_key(name)
      self.class.to_ssdb_attr_key(name, id)
    end

    private

    def touch_db_column(names)
      names == true ? touch : touch(*names)
    end

    module ClassMethods
      def ssdb_attr_names
        @ssdb_attr_names ||= []
      end

      def to_ssdb_attr_key(name, id)
        "#{self.name.tableize}:#{id}:#{name}"
      end


      # ssdb_attr :content,        :string,   default: 0, touch: true
      # ssdb_attr :writer_version, :integer,  default: 0, touch: [:field1, :field2, :field3]
      #
      # [counter description]
      # @param name [type] [description]
      # @param name [type] [description]
      # @param options={} [type] [description]
      # @param block [description]
      #
      # @return [type] [description]
      def ssdb_attr(name, type, options={})
        unless %i(string integer).include?(type)
          raise "Type not supported, only `:string` and `:integer` are supported now."
        end

        self.ssdb_attr_names << name

        define_method(name) do
          conversion = type == :string ? :to_s : :to_i
          value = SSDBAttr.pool.with { |conn| conn.get("#{to_ssdb_attr_key(name)}") }
          (value || options[:default]).send(conversion)
        end

        define_method("#{name}=") do |val|
          SSDBAttr.pool.with { |conn| conn.set("#{to_ssdb_attr_key(name)}", val) }
          touch_db_column(options[:touch]) if options[:touch].present?
        end

        define_method("#{name}_will_change!") do
          attribute_will_change!(name)
        end

        define_method("#{name}_changed?") do
          attribute_changed?(name)
        end
      end
    end
  end
end
