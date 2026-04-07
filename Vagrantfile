Vagrant.configure("2") do |config|

  # 全VMに共通する設定をここに書く
  config.vm.box = "ubuntu/jammy64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 512
    vb.cpus   = 1
  end

  # lb01
  config.vm.define "lb01" do |lb|
    lb.vm.hostname = "lb01"
    lb.vm.network "private_network", ip: "192.168.56.10"
  end

  # web01
  config.vm.define "web01" do |web|
    web.vm.hostname = "web01"
    web.vm.network "private_network", ip: "192.168.56.11"
  end

  # web02
  config.vm.define "web02" do |web|
    web.vm.hostname = "web02"
    web.vm.network "private_network", ip: "192.168.56.12"
  end

end