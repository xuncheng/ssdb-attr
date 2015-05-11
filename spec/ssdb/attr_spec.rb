require 'spec_helper'

class Dummy
  include SSDB::Attr

  attr_accessor :id

  ssdb_attr :title,   :string
  ssdb_attr :version, :integer, default: 22
  ssdb_attr :content, :string,  touch: true

  def initialize
    @id = Random.rand(10000)
  end

  def candies
    15
  end
end

describe SSDB::Attr do
  describe "method definition" do

  end

  describe "default value" do
    it 'should set default value correctly' do
      dummy = Dummy.new

      dummy.version.must_equal 22
    end
  end

  describe "Type conversion" do
    it "should convert to string correctly" do
      dummy = Dummy.new

      dummy.title = 120
      dummy.title.must_equal '120'
    end

    it "should convert to integer correctly" do
      dummy = Dummy.new

      dummy.version = '120'
      dummy.version.must_equal 120
    end
  end
end
