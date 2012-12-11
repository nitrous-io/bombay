require 'spec_helper'

describe Bombay::ServerCollection do
  let!(:role)           { 'nagios' }
  let!(:role_directory) { File.join(Bombay::ROOT, "ansible", role) }
  let!(:config_file)    { File.join(role_directory, "config.yml")  }

  before do
    config = File.read(File.join(Bombay::ROOT, "spec", "fixtures", "nagios_config.yml"))
    FakeFS.activate!

    FileUtils.rm_rf(role_directory) if File.exists?(role_directory)
    FileUtils.mkdir_p(role_directory)
    FileUtils.mkdir_p(File.join(Bombay::ROOT, 'ansible', 'vars_files'))
    File.open(config_file, 'w') { |f| f.puts config }

    setup_aws_credentials!
  end

  after do
    FakeFS.deactivate!
    ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_SECRET_ACCESS_KEY'] = nil
  end

  describe "#ansible_hosts" do
    before do
      @server_collection = Bombay::ServerCollection.parse(role)
    end

    context "with the all servers in the region provisioned" do
      context "(ap-southeast-1)" do
        before do
          @server_collection.current_region = 'ap-southeast-1'
          @server_collection.environment = 'development'
          @server_collection.to_a.each { |s| create_server(s) }
        end

        after do
          destroy_all_servers('ap-southeast-1')
          destroy_all_servers('us-west-1')
        end

        it "should return a string which contains the servers and its associated vars" do
          @server_collection.ansible_hosts.should == "[nagios]\nnagios-server-apse1.action.io nagios_email=\"nagios-apse-1@nagios.com\" nagios_http_port=\"80\" nagios_https_port=\"443\" nagios_password=\"password_development\" nagios_user=\"user_development\"\nnagios-server-apse2.action.io nagios_email=\"nagios-apse-2@nagios.com\" nagios_http_port=\"80\" nagios_https_port=\"443\" nagios_password=\"password_development\" nagios_user=\"user_development\""
        end
      end

      context "(us-west-1)" do
        before do
          @server_collection.current_region = 'us-west-1'
          @server_collection.environment = 'production'
          @server_collection.to_a.each { |s| create_server(s) }
        end

        after do
          destroy_all_servers('ap-southeast-1')
          destroy_all_servers('us-west-1')
        end

        it "should return a string which contains the servers and its associated vars" do
          @server_collection.ansible_hosts.should == "[nagios]\nnagios-server-usw1.action.io nagios_email=\"nagios-usw-1@nagios.com\" nagios_http_port=\"80\" nagios_https_port=\"443\" nagios_password=\"password_production\" nagios_user=\"user_production\""
        end
      end
    end

    context "with only some of the servers in the region provisioned" do
      before do
        @server_collection.current_region = 'ap-southeast-1'
        @server_collection.environment = 'development'
        create_server(@server_collection.to_a.first)
      end

      after do
        destroy_all_servers('ap-southeast-1')
        destroy_all_servers('us-west-1')
      end

      it "should return a string which contains the servers and its associated vars" do
        @server_collection.ansible_hosts.should == "[nagios]\nnagios-server-apse1.action.io nagios_email=\"nagios-apse-1@nagios.com\" nagios_http_port=\"80\" nagios_https_port=\"443\" nagios_password=\"password_development\" nagios_user=\"user_development\""
      end
    end
  end

  describe "#cache_sensitive_vars!" do
    before do
      @server_collection = Bombay::ServerCollection.parse(role)
      @server_collection.current_region = 'ap-southeast-1'
      @server_collection.environment = 'development'

      @server_collection.stub(:ask).and_return('aws_access_key_id', 'aws_secret_access_key')
      @server_collection.stub(:ask_editor).and_return 'gh_private_key'
    end

    context "doesn't already have sensitive vars cached" do
      it "should cache sensitive variables in files" do
        @server_collection.cache_sensitive_vars!

        sensitive_vars_file_1 = File.join(Bombay::ROOT, 'ansible', 'vars_files', 'github_private_key.yml')
        sensitive_vars_file_2 = File.join(Bombay::ROOT, 'ansible', 'vars_files', 's3cfg.development.yml')

        sensitive_vars_1 = YAML.load File.read(sensitive_vars_file_1)
        sensitive_vars_2 = YAML.load File.read(sensitive_vars_file_2)

        sensitive_vars_1['github_key'].should == 'gh_private_key'
        sensitive_vars_2['aws_access_key_id'].should == 'aws_access_key_id'
        sensitive_vars_2['aws_secret_access_key'].should == 'aws_secret_access_key'
      end
    end

    context "has sensitive vars cached" do
      before do
        @sensitive_vars_file_1 = File.join(Bombay::ROOT, 'ansible', 'vars_files', 'github_private_key.yml')
        @sensitive_vars_file_2 = File.join(Bombay::ROOT, 'ansible', 'vars_files', 's3cfg.development.yml')

        File.open(@sensitive_vars_file_1, 'w') { |f| f.puts({"github_key" => "gh_private_key"}.to_yaml) }
        File.open(@sensitive_vars_file_2, 'w') { |f| f.puts({"aws_access_key_id" => "aws_access_key_id", "aws_secret_access_key" => "aws_secret_access_key"}.to_yaml) }
      end

      it "should cache sensitive variables in files without prompting for variables" do
        @server_collection.should_not_receive(:ask_editor).with("Replace this line with the private key used by the box to pull from Github repos:")
        @server_collection.should_not_receive(:ask).with("AWS Access Key ID (needed to pull stuff from S3):")
        @server_collection.should_not_receive(:ask).with("AWS Secret Access Key (needed to pull stuff from S3):")

        @server_collection.cache_sensitive_vars!

        sensitive_vars_1 = YAML.load File.read(@sensitive_vars_file_1)
        sensitive_vars_2 = YAML.load File.read(@sensitive_vars_file_2)

        sensitive_vars_1['github_key'].should == 'gh_private_key'
        sensitive_vars_2['aws_access_key_id'].should == 'aws_access_key_id'
        sensitive_vars_2['aws_secret_access_key'].should == 'aws_secret_access_key'
      end
    end
  end

  describe "#set_environment!" do
    before do
      @server_collection = Bombay::ServerCollection.parse(role)
    end

    context "user enters an environment correctly on the first attempt" do
      before do
        @server_collection.stub(:ask).and_return('development')
      end

      it "should set the regions instance variable with the picked region" do
        @server_collection.should_receive(:ask).once.and_return('development')
        @server_collection.set_environment!
        @server_collection.environment.should == 'development'
      end
    end

    context "user enters a region incorrectly twice and then returns a correct one" do
      before do
        @server_collection.stub(:ask).and_return('foo', 'bar', 'all', 'production')
      end

      it "should set the regions instance variable with the picked region" do
        @server_collection.should_receive(:ask).exactly(4).times
        @server_collection.set_environment!
        @server_collection.environment.should == 'production'
      end
    end
  end

  describe "#set_regions!" do
    before do
      @server_collection = Bombay::ServerCollection.parse(role)
    end

    context "user enters a region correctly on the first attempt" do
      before do
        @server_collection.stub(:ask).and_return('ap-southeast-1')
      end

      it "should set the regions instance variable with the picked region" do
        @server_collection.should_receive(:ask).once.and_return('ap-southeast-1')
        @server_collection.set_regions!
        @server_collection.regions.should == ['ap-southeast-1']
      end
    end

    context "user enters a region incorrectly twice and then returns a correct one" do
      before do
        @server_collection.stub(:ask).and_return('foo', 'bar', 'ap-southeast-1')
      end

      it "should set the regions instance variable with the picked region" do
        @server_collection.should_receive(:ask).exactly(3).times
        @server_collection.set_regions!
        @server_collection.regions.should == ['ap-southeast-1']
      end
    end

    context "user enters the word 'all'" do
      before do
        @server_collection.stub(:ask).and_return('all')
      end

      it "should set the regions instance variable with the picked region" do
        @server_collection.should_receive(:ask).once.and_return('all')
        @server_collection.set_regions!
        @server_collection.regions.should == ['ap-southeast-1', 'us-west-1']
      end
    end
  end

  describe ".parse" do
    context "role does not exist in Bombay::ROOT/ansible" do
      before do
        FileUtils.rm_rf(role_directory)
      end

      it "should return nil" do
        Bombay::ServerCollection.parse(role).should be_nil
      end
    end

    context "role does exist in Bombay::ROOT/ansible" do
      context "config.yml is invalid YAML" do
        before do
          File.open(config_file, 'w') { |f| f.puts "commercial-at: @text" }
        end

        it "should return nil" do
          Bombay::ServerCollection.parse(role).should be_nil
        end
      end

      context "config.yml is valid YAML" do
        it "should return a server collection" do
          server_collection = Bombay::ServerCollection.parse(role)
          server_collection.class.should == Bombay::ServerCollection
          server_collection.size.should == 3
        end

        it "should set the role in the server collection" do
          server_collection = Bombay::ServerCollection.parse(role)
          server_collection.role.should == role
        end

        it "should contain an array of Bombay::Server objects" do
          server_collection = Bombay::ServerCollection.parse(role)
          servers = server_collection.to_a

          servers[0].hostname.should == 'nagios-server-apse1.action.io'
          servers[0].size.should == 'm1.small'
          servers[0].region.should == 'ap-southeast-1'
          servers[0].ami.should == 'ami-deadbeef'
          servers[0].environment.should == 'development'
          servers[0].vars.should == { "nagios_http_port" => 80, "nagios_https_port" => 443, "nagios_user" => "user_development", "nagios_password" => "password_development", "nagios_email" => "nagios-apse-1@nagios.com" }

          servers[1].hostname.should == 'nagios-server-apse2.action.io'
          servers[1].size.should == 'm1.large'
          servers[1].region.should == 'ap-southeast-1'
          servers[1].ami.should == 'ami-deadbeef'
          servers[1].environment.should == 'development'
          servers[1].vars.should == { "nagios_http_port" => 80, "nagios_https_port" => 443, "nagios_user" => "user_development", "nagios_password" => "password_development", "nagios_email" => "nagios-apse-2@nagios.com" }

          servers[2].hostname.should == 'nagios-server-usw1.action.io'
          servers[2].size.should == 'm1.small'
          servers[2].region.should == 'us-west-1'
          servers[2].ami.should == 'ami-deadbeef'
          servers[2].environment.should == 'production'
          servers[2].vars.should == { "nagios_http_port" => 80, "nagios_https_port" => 443, "nagios_user" => "user_production", "nagios_password" => "password_production", "nagios_email" => "nagios-usw-1@nagios.com" }

          sensitive_vars = server_collection.sensitive_vars
          sensitive_vars['github_private_key']['context'].should == 'global'
          sensitive_vars['s3cfg']['context'].should == 'environment'
        end
      end
    end
  end
end
