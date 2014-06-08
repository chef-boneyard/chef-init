require 'spec_helper'

describe ChefInit::Exceptions::ProcessSupervisorNotRunning do
  it { should be_a_kind_of(RuntimeError) }
end

describe ChefInit::Exceptions::OmnibusInstallNotFound do
  it { should be_a_kind_of(RuntimeError) }
end
