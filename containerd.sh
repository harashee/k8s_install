#!/bin/bash

display_usage() {
  echo -e "\nUsage: $0 -r=master|worker \n" 
  echo -e "Example: ./containerd.sh -r=master \n" 
}
if [  $# -ne 1 ] 
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
echo -e $VALUE


sudo apt -y install curl apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
kubectl version --client && kubeadm version
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io
sudo su -

mkdir -p /etc/containerd
containerd config default>/etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
systemctl status  containerd
sed -i -e 's/systemd_cgroup = false/systemd_cgroup = true/g' /etc/containerd/config.toml
lsmod | grep br_netfilter
sudo systemctl enable kubelet
exit

    if [[ "${VALUE}" != "master" ]]; then
        exit 1
    else
        sudo kubeadm config images pull
        sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock
        sudo kubeadm init --kubernetes-version stable-1.22
        kubectl get node -o wide
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        kubectl get node -o wide
        kubectl cluster-info
        kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
        kubectl get node -o wide

    fi

fi