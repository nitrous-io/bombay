require 'spec_helper'

describe Bombay::SecurityGroupCollection do
  describe "initialize" do
    it "should initialize instance variables" do
      collection = Bombay::SecurityGroupCollection.new('ap-southeast-1')
      collection.region.should == 'ap-southeast-1'
    end
  end

  describe "#provision" do
    let!(:sg_1) { Bombay::SecurityGroup.new('sg_1', 'ap-southeast-1') }
    let!(:sg_2) { Bombay::SecurityGroup.new('sg_2', 'ap-southeast-1') }
    let!(:sg_collection) { Bombay::SecurityGroupCollection.new('ap-southeast-1') }

    before do
      Bombay::SecurityGroup.any_instance.stub(:provision)
      sg_collection.add sg_1
      sg_collection.add sg_2
    end

    it "should call provision! on all the security groups in the collection" do
      sg_1.should_receive(:provision).ordered
      sg_2.should_receive(:provision).ordered

      sg_collection.provision
    end
  end

  describe ".parse" do
    before do
      fixture_content = File.read(File.join(Bombay::ROOT, 'spec', 'fixtures', 'security_groups_fixture.yml'))
      FakeFS.activate!

      FileUtils.mkdir_p(File.join(Bombay::ROOT, 'config'))
      File.open(File.join(Bombay::ROOT, 'config', 'security_groups.yml'), 'w') do |f|
        f.puts(fixture_content)
      end
    end

    after do
      FakeFS.deactivate!
    end

    it "should initialize a SecurityGroupCollection object with all the SecurityGroup objects init'ed" do
      collection = Bombay::SecurityGroupCollection.parse('ap-southeast-1')
      collection.class.should == Bombay::SecurityGroupCollection

      collection.size.should == 3
      sg_1, sg_2, sg_3 = collection.to_a

      sg_1.name.should == 'sg_1'
      sg_1.region.should == 'ap-southeast-1'
      sg_1.rules.size.should == 2
      sg_1.rules[0].port_range.should == (443..443)
      sg_1.rules[0].protocol.should == 'tcp'
      sg_1.rules[0].source.should == '0.0.0.0/0'
      sg_1.rules[1].port_range.should == (65100..65100)
      sg_1.rules[1].protocol.should == 'tcp'
      sg_1.rules[1].source.should == '0.0.0.0/0'

      sg_2.name.should == 'sg_1_1'
      sg_2.region.should == 'ap-southeast-1'
      sg_2.rules.size.should == 1
      sg_2.rules[0].port_range.should == (80..80)
      sg_2.rules[0].protocol.should == 'tcp'
      sg_2.rules[0].source.should == '0.0.0.0/0'

      sg_3.name.should == 'sg_2'
      sg_3.region.should == 'ap-southeast-1'
      sg_3.rules.size.should == 3
      sg_3.rules[0].port_range.should == (3000..9000)
      sg_3.rules[0].protocol.should == 'tcp'
      sg_3.rules[0].source.should == '0.0.0.0/0'
      sg_3.rules[1].port_range.should == (10000..20000)
      sg_3.rules[1].protocol.should == 'tcp'
      sg_3.rules[1].source.should == '0.0.0.0/0'
      sg_3.rules[2].port_range.should == (65100..65100)
      sg_3.rules[2].protocol.should == 'tcp'
      sg_3.rules[2].source.should == 'role_1,role_1_1'
    end
  end
end
