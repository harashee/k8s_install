#!/bin/bash

display_usage() {
  echo -e "\nUsage: $0 --sock=<cri socket path> --role=master|worker\n" 
  echo -e "Example: ./containerd.sh --sock=/var/run/docker.sock --role=master\n" 
}


if [  $# -ne 2 ] 
then 
  display_usage
  exit 1
else
    while [ "$1" != "" ]; do
        PARAM=`echo $1 | awk -F= '{print $1}'`
        VALUE=`echo $1 | awk -F= '{print $2}'`
        case $PARAM in
            -h | --help)
                display_usage
                exit
                ;;
            -v | --sock)
                sock=$VALUE
                ;;
            -r | --role)
                role=$VALUE
                ;;
            *)
                echo "ERROR: unknown parameter \"$PARAM\""
                display_usage
                exit 1
                ;;
        esac
        shift
    done
fi
# Add repo and Install packages
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io docker-ce docker-ce-cli

# Create required directories
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker
if [[ "${role}" != "master" ]]; then
    echo -e "==============================================================="
    echo -e "Successfully Installed k8s ${role} node with docker as container runtime"
    echo -e "==============================================================="
    exit 1
else
    lsmod | grep br_netfilter
    sudo systemctl enable kubelet
    sudo kubeadm config images pull --cri-socket ${sock}
fi