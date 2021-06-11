ENV['vault_ver']||="1.7.1"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.network "private_network", type: "dhcp"
  config.vm.hostname = "vault"
  config.vm.provision "provisioner script", type: "shell", path: "scripts/vault_setup.sh", args: "#{ENV['vault_ver']}"
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 2
  end
end
