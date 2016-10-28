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

  let(:post) { Post.create(updated_at: 1.day.ago, saved_at: 1.day.ago, changed_at: 1.day.ago) }
  let(:custom_id_field) { CustomIdField.create(uuid: 123) }

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

  describe ".ssdb_attr_key" do
    it "should return correct key" do
      expect(post.send(:ssdb_attr_key, "name")).to eq("posts:#{post.id}:name")
    end
  end

  # describe ".update_ssdb_attrs" do
  #   context "with symbol keys" do
  #     it "should update values correctly" do
  #       post.update_ssdb_attrs(title: "note one", content: "testing!!!", version: 1)
  #       post.reload_ssdb_attrs

  #       expect(post.title).to eq("note one")
  #       expect(post.content).to eq("testing!!!")
  #       expect(post.version).to eq(1)
  #     end
  #   end
  # end

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

  context "custom id field" do
    it "should use the custom id correctly" do
      expect(CustomIdField.ssdb_attr_id_field).to eq(:uuid)
      expect(custom_id_field.send(:ssdb_attr_key, "content")).to eq("custom_id_fields:123:content")
    end
  end
end
