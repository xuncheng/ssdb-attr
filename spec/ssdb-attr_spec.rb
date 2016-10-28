require 'spec_helper'

describe SSDBAttr do
  describe "#setup" do
    it "should setup a ssdb connection pool" do
      expect(SSDBAttr.pool).not_to be_nil
    end
  end
end
