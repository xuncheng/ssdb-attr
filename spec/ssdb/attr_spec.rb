require 'spec_helper'

class Post < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :title,   :string, touch: [:content_updated_at]
  ssdb_attr :content, :string, touch: true
  ssdb_attr :version, :integer, default: 22

  # touch_ssdb_attr [:title, :content], touch: [:content_at]
  #
  #
  # dummy.update_ssdb_attrs(title: 'abc', content: 'cbd')
  #
  # before_update_ssdb_attributes args*
  # after_update_ssdb_attributes :touch_updated_at
end

describe SSDB::Attr do
  describe "#update_ssdb_attrs" do
    if 'should correctly set values'
    end
  end

  describe "#ssdb_attr" do
    # it 'should maintain the array of defined attr names' do
    #   dummy = Dummy.new
    #
    #   Dummy.ssdb_attr_names.count.must_equal 3
    #   Dummy.ssdb_attr_names.include? :title
    #   Dummy.ssdb_attr_names.include? :content
    #   Dummy.ssdb_attr_names.include? :version
    # end

    it 'should set default value correctly' do
      post = Post.create

      post.version.must_equal 22
    end

    it "should convert to string correctly" do
      post = Post.create

      post.title = 120
      post.title.must_equal '120'
    end

    it "should convert to integer correctly" do
      post = Post.create

      post.version = '120'
      post.version.must_equal 120
    end
  end
end
