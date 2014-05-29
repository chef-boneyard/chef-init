require 'spec_helper'
require 'chef-init/cli'
require 'stringio'

describe ChefInit::CLI do
  let(:argv) { [] }
  let(:max_retries) { 5 }
  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  def stdout
    stdout_io.string
  end

  def stderr
    stderr_io.string
  end 
  
  subject(:cli) do
    ChefInit::CLI.new(argv, max_retries).tap do |c|
      c.stub(:stdout).and_return(stdout_io)
      c.stub(:stderr).and_return(stderr_io)
    end
  end

  def run_cli(expected_exit_code=nil)
    cli.run
  end
  
  context "given no arguments or options" do
    it "prints the help message"
  end

  context "given an invalid/unknown option" do
    it "given an 'unknown option' message and the help output"
  end

  describe "#run" do
    let(:chef_client) { double("chef-client") }
    let(:runsvdir_process) { double("exec runsvdir -P") }

    before do
      cli.stub(:wait_for_runit).and_return(true)
      cli.stub(:run_chef_client).and_return(chef_client)
      cli.stub(:launch_runsvdir).and_return(runsvdir_process)
    end

    it "should parse options" do
      expect(cli).to receive(:handle_options)
      cli.run
    end

    it "should exec runsvdir" do
      expect(cli).to receive(:launch_runsvdir)
      cli.run
    end

    it "should run chef-client" do
      expect(cli).to receive(:fork) do |&block|
        expect(cli).to receive(:wait_for_runit)
        expect(cli).to receive(:run_chef_client)
        block.call
      end
      cli.run
    end

    context "when --build flag is passed in" do
      let(:argv) { %w[ -c FAKE --build] }

      it "should send HUP signal to runsvdir when chef-client completes" do
        Process.stub(:pid).and_return(111)
        expect(cli).to receive(:fork) do |&block|
          expect(Process).to receive(:kill).with("HUP", 111)
          block.call
        end
        cli.run
      end
    end
  end

  describe "#wait_for_runit" do

    it "should check to see if process supervisor is running" do
      cli.stub(:supervisor_running?).with("runsvdi[r]").and_return(true)
      expect(cli).to receive(:supervisor_running?).with("runsvdi[r]")
      cli.wait_for_runit
    end

    context "when process supervisor it not running yet" do
      before do
        cli.stub(:supervisor_running?).with("runsvdi[r]").and_raise ChefInit::Exceptions::ProcessSupervisorNotRunning
        cli.stub(:sleep)
      end

      it "exponentially backs off before finally exiting" do
        expect(cli).to receive(:sleep).with(2)  
        expect(cli).to receive(:sleep).with(4)  
        expect(cli).to receive(:sleep).with(8)  
        expect(cli).to receive(:sleep).with(16)  
        expect(cli).to receive(:exit).with(1)
        cli.wait_for_runit
      end
    end

    context "when process supervisor is running" do
      before do
        cli.stub(:supervisor_running?).with("runsvdi[r]").and_return(true)
      end

      it "does not exit" do
        expect(cli).not_to receive(:exit).with(1)
        cli.wait_for_runit
      end
    end

    context "when process supervisor does not start in alloted time" do
      let(:max_retries) { 0 }

      before do
        cli.stub(:supervisor_running?).with("runsvdi[r]").and_raise ChefInit::Exceptions::ProcessSupervisorNotRunning
      end

      it "exits with return code 1" do
        expect(cli).to receive(:exit).with(1)
        cli.wait_for_runit
      end
    end
  end

  describe "#launch_runsvdir" do
    before do
      cli.stub(:exec)
    end

    it "should exec runsvdir process" do
      expect(cli).to receive(:exec).with("/opt/chef/embedded/bin/runsvdir -P /opt/chef/service 'log: #{ '.' * 395 }'")  
      cli.launch_runsvdir
    end
  end

  describe "#run_chef_client" do
    let(:chef_runner) { double("ChefRunner", :converge => nil) }

    it "should converge the chef_runner" do
      cli.stub(:chef_runner).and_return(chef_runner)
      expect(chef_runner).to receive(:converge)
      cli.run_chef_client
    end
  end

  describe "#supervisor_running" do
    let(:valid) { double("Running Process", :stdout => "docker  99928  runsvdir -P /opt/chef/service", :exitstatus => 0) }
    let(:invalid) { double("NonRunning Process", :stdout => "", :exitstatus => 1) }

    context "when supervisor is running" do
      it "returns true" do
        cli.stub(:system_command).with("ps aux | grep runsvdi[r]").and_return(valid)
        running = cli.supervisor_running?("runsvdi[r]")
        expect(running).to eql(true)
      end
    end 

    context "when supervisor is not running" do
      it "raises an error" do
        cli.stub(:system_command).with("ps aux | grep runsvdi[r]").and_return(invalid)
        expect{ cli.supervisor_running?("runsvdi[r]") }.to raise_error(ChefInit::Exceptions::ProcessSupervisorNotRunning)
      end
    end
  end
  
end
