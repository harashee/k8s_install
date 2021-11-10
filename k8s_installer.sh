#!/bin/bash

$docker="/var/run/docker.sock"
$containerd="/run/containerd/containerd.sock"
$crio="/var/run/crio/crio.sock"

display_usage() {
  echo -e "\nUsage: $0 --ver=<k8s version>--cri=containerd --net=calico --role=master|worker\n" 
  echo -e "Example: ./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=master \n" 
}
if [  $# -ne 4 ] 
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
            -v | --ver)
                ver=$VALUE
                ;;
            -r | --role)
                role=$VALUE
                ;;
            -c | --cri)
                cri=$VALUE
                ;;
            -n | --net)
                net=$VALUE
                ;;
            *)
                echo "ERROR: unknown parameter \"$PARAM\""
                display_usage
                exit 1
                ;;
        esac
        shift
    done
echo -e "Starting the K8s Installation with below configs"
echo "==============================================================="
echo -e "K8s version ====> ${ver}"
echo -e "Container runtime ====> ${cri}"
echo -e "CNI ====> ${net}"
echo -e "Role ====> ${role}"
echo -e "==============================================================="

sudo apt -y install curl apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt -y install vim git curl wget kubelet=${ver}.1-00 kubeadm=${ver}.1-00 kubectl=${ver}.1-00
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

    if [[ "${cri}" == "containerd" ]]; then
        sudo apt install -y containerd.io
        sudo su -
        mkdir -p /etc/containerd
        containerd config default>/etc/containerd/config.toml
        sudo systemctl restart containerd
        sudo systemctl enable containerd
        systemctl status  containerd
        sed -i -e 's/systemd_cgroup = false/systemd_cgroup = true/g' /etc/containerd/config.toml
        exit
        if [[ "${role}" != "master" ]]; then
            echo -e "==============================================================="
            echo -e "Successfully Installed k8s ${ver} ${role} node with ${net} CNI"
            echo -e "==============================================================="
            exit 1
        lsmod | grep br_netfilter
        sudo systemctl enable kubelet
        sudo kubeadm config images pull
        sudo kubeadm config images pull --cri-socket ${containerd}
    fi


    else

        if [[ "${cri}" == "containerd" ]]; then
            sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock
        fi
        
        sudo kubeadm init --kubernetes-version stable-{$ver}.1-00
        kubectl get node -o wide
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        kubectl cluster-info
        if [[ "${net}" == "calico" ]]; then
            kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
        fi
        kubectl get node -o wide

    fi
echo -e "==============================================================="
echo -e "Successfully Installed k8s ${ver} ${role} node with ${net} CNI"
echo -e "==============================================================="
fi