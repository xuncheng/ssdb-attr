require 'spec_helper'

describe SSDBAttr do
  describe "#setup" do
    it "should setup a ssdb connection pool" do
      SSDBAttr.pool.wont_be_nil
    end
  end
end
