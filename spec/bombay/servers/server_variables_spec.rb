require 'spec_helper'

describe Bombay::ServerVariables do
  let!(:server_variables) { Bombay::ServerVariables.new({x:1,y:2}) }

  describe "#to_hash" do
    it "should return a hash" do
      server_variables.to_hash.should == {x:1, y:2}
    end
  end

  describe "#to_s" do
    it "should return a string which has values quoted" do
      server_variables.to_s.should == 'x="1" y="2"'
    end
  end

  describe "#merge!" do
    context "with a hash" do
      s1 = Bombay::ServerVariables.new(a:1, b:2)
      s1.merge!(c:3, b:0)
      s1.to_hash.should == {a:1, b:0, c:3}
    end

    context "with another Bombay::ServerVariables object" do
      s1 = Bombay::ServerVariables.new(a:1, b:2)
      s2 = Bombay::ServerVariables.new(c:4, b:0)
      s1.merge!(s2)
      s1.to_hash.should == {a:1, b:0, c:4}
    end
  end
end

