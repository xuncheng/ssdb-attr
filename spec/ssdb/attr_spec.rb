require "spec_helper"

class Post < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :name, :string
  ssdb_attr :int_version, :integer
  ssdb_attr :default_title, :string, default: "Untitled"
  ssdb_attr :title, :string
  ssdb_attr :content, :string
  ssdb_attr :version, :integer, default: 1

  # before_update_ssdb_attrs :before1, :before2
  # after_update_ssdb_attrs :after1, :after2

  def callback_out
    @callback_out ||= []
  end

  [:before1, :before2, :after1, :after2].each do |name|
    define_method(name) do
      callback_out << name
    end
  end
end

class CustomIdField < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :content, :string
  ssdb_attr_id_field :uuid
end

describe SSDB::Attr do

  before(:all) do
    SSDBAttr.pool.with { |conn| conn.flushdb }

    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute "DELETE FROM #{table}"
    end
  end

  context "Post" do
    let(:post) { Post.create(updated_at: 1.day.ago, saved_at: 1.day.ago, changed_at: 1.day.ago) }

    describe "internal variables" do
      it "should set `@ssdb_attr_names` correctly"  do
        ssdb_attr_names = Post.instance_variable_get(:@ssdb_attr_names)
        expect(ssdb_attr_names).to match_array(["name", "int_version", "default_title", "title", "content", "version"])
      end
    end

    describe "respond to methods" do
      it do
        expect(post.respond_to?(:name)).to be_truthy
        expect(post.respond_to?(:name=)).to be_truthy
        expect(post.respond_to?(:name_was)).to be_truthy
        expect(post.respond_to?(:name_change)).to be_truthy
        expect(post.respond_to?(:name_changed?)).to be_truthy
        expect(post.respond_to?(:restore_name!)).to be_truthy
        expect(post.respond_to?(:name_will_change!)).to be_truthy
      end
    end

    context ".attribute=" do
      it "`.attribute=` should change the value of current object but not in the SSDB server" do
        post.name = "foobar"

        expect(post.name).to eq("foobar")
        expect(SSDBAttr.pool.with { |conn| conn.get(post.send(:ssdb_attr_key, :name)) }).not_to eq("foobar")
      end

      it "`.attribute_was` should return the value before change" do
        post.default_title = "foobar"
        post.int_version = 199

        expect(post.default_title_was).to eq("Untitled")
        expect(post.int_version).to eq(199)
      end

      it "`.attribute_change` should return the values before and after change" do
        post.name = "foobar"
        post.int_version = 199

        expect(post.name_change).to match_array(["", "foobar"])
        expect(post.int_version_change).to match_array([0, 199])
      end

      it "`.attribute_changed?` should return true for the changed attribute" do
        post.name = "foobar"
        post.int_version = 199

        expect(post.name_changed?).to be_truthy
        expect(post.int_version_changed?).to be_truthy
        expect(post.title_changed?).to be_falsey
        expect(post.content_changed?).to be_falsey
      end

      it "`.restore_attribute!` should restore the changed attributes" do
        post.default_title = "foobar"
        post.int_version = 199

        post.restore_default_title!

        expect(post.default_title).to eq("Untitled")
        expect(post.int_version).to eq(199)
      end

      it "`.attribute_will_change!` should invoke `attributes_will_change!` on attribute name" do
        expect(post).to receive(:attribute_will_change!).with(:default_title)
        post.default_title_will_change!
      end
    end

    describe ".reload" do
      it "should reload changed SSDB attributes" do
        post.default_title = "foobar"
        post.reload
        expect(post.default_title).to eq("Untitled")
      end
    end

    describe ".ssdb_attr_key" do
      it "should return correct key" do
        expect(post.send(:ssdb_attr_key, "name")).to eq("posts:#{post.id}:name")
      end
    end

    context "type: :integer" do
      it "default value should be 0" do
        expect(post.int_version).to eq(0)
      end

      it "should hold integer value and return it" do
        post.int_version = 4
        expect(post.int_version).to eq(4)
      end
    end

    context "type: :string" do
      it "set default value should work" do
        expect(post.default_title).to eq("Untitled")
      end
    end
  end

  context "CustomIdField" do
    let(:custom_id_field) { CustomIdField.create(:uuid => 123) }

    it "should use the custom id correctly" do
      expect(CustomIdField.ssdb_attr_id_field).to eq(:uuid)
      expect(custom_id_field.send(:ssdb_attr_key, "content")).to eq("custom_id_fields:123:content")
    end
  end
end
