module SSDB
  module Attr
    extend ActiveSupport::Concern

    def to_ssdb_attr_key(name)
      "#{self.class.to_s.underscore.pluralize}:#{self.id}:#{name}"
    end

    module ClassMethods
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
            self.send("touch_ssdb_attr_#{name}".to_sym) if self.respond_to?("touch_ssdb_attr_#{name}".to_sym)
          end
        end

        if options[:touch].present?
          define_method("touch_ssdb_attr_#{name}") do
            t = Time.now

            if options[:touch].kind_of?(Array)
              options[:touch].each do |field|
                self.update(field.to_sym, t) if ActiveRecord::Base.connection.column_exists?(self.class.table_name, field.to_sym, :datetime)
              end
            else
              self.update(:updated_at, t) if ActiveRecord::Base.connection.column_exists?(self.class.table_name, :updated_at, :datetime)
            end
          end
        end
      end
    end
  end
end
