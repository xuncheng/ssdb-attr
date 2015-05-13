require 'spec_helper'

class Post < ActiveRecord::Base
  include SSDB::Attr

  ssdb_attr :title,           :string, touch: [:content_updated_at]
  ssdb_attr :content,         :string, touch: true
  ssdb_attr :version,         :integer, default: 22
  ssdb_attr :counter,         :integer, default: 4

  before_update_ssdb_attrs  :before_callback1, :before_callback2
  after_update_ssdb_attrs   :after_callback1, :after_callback2

  def before_callback1
    puts "before callback 1"

    if title_changed?
      puts "title changed detected."
    end
  end

  def before_callback2
    puts "before callback 2"
  end

  def after_callback1
    puts "after callback 1"
  end

  def after_callback2
    puts "after callback 2"
  end

  # touch_ssdb_attr [:title, :content], touch: [:content_at]
  #
  # dummy.update_ssdb_attrs(title: 'abc', content: 'cbd')
  #
  # before_update_ssdb_attributes args*
  # after_update_ssdb_attributes :touch_updated_at
end

describe SSDB::Attr do

  describe "method created" do
  end

  describe "#update_ssdb_attrs" do
    if 'should correctly set values'
      post = Post.create

      post.update_ssdb_attrs(title: :bar)

      # title =  'foo'
      # content = 'bar'
      #
      # title.must_equal 'foo'
      # content.must_equal 'bar'
      #
      #post.title.must_equal 'foo'
      #post.content.must_equal 'bar'
    end
  end

  describe "#ssdb_attr" do
    it 'should set default value correctly' do
      post = Post.create

      post.counter.must_equal 4
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
