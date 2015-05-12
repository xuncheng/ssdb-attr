module SSDB
  module Attr
    extend ActiveSupport::Concern

    def to_ssdb_attr_key(name)
      "#{self.class.to_s.underscore.pluralize}:#{self.id}:#{name}"
    end

    module ClassMethods
      def ssdb_attr_names
        @ssdb_attr_names = [] if @ssdb_attr_names.nil?
        @ssdb_attr_names
      end

      def update_ssdb_attrs(data={})
        attr_names = data.keys && self.ssdb_attr_names

        SSDBAttr.pool.with do |conn|
          attr_names.each do |name|
            conn.set("#{self.to_ssdb_attr_key(name)}", data[name])
          end
        end
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

        if ![:string, :integer].include?(type)
          raise "Type not supported, only `:string` and `:integer` are supported now."
        end

        self.ssdb_attr_names ||= []
        self.ssdb_attr_names << name

        define_method(name) do
          conversion = type == :string ? :to_s : :to_i

          value = SSDBAttr.pool.with do |conn|
            conn.get("#{self.to_ssdb_attr_key(name)}")
          end

          value.try(conversion) || options[:default]
        end

        define_method("#{name}=") do |v|
          SSDBAttr.pool.with do |conn|
            conn.set("#{self.to_ssdb_attr_key(name)}", v)
          end

          self.send("touch_ssdb_attr_#{name}".to_sym) if self.respond_to?("touch_ssdb_attr_#{name}".to_sym)
        end

        if options[:touch].present?
          define_method("touch_ssdb_attr_#{name}") do
            if options[:touch].kind_of?(Array)
              touch(*options[:touch])
            else
              touch(:updated_at)
            end
          end
        end
      end

      def after_update_ssdb_attributes(*args)
        define_method("perform_ssdb_attr_after_callbacks") do
        end
      end

      def before_update_ssdb_attributes(*args)
      end

    end
  end
end
