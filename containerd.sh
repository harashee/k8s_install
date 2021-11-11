display_usage() {
  echo -e "\nUsage: $0 --sock=<cri socket path> --role=master|worker\n" 
  echo -e "Example: ./containerd.sh --sock=/run/containerd/containerd.sock --role=master\n" 
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
                ver=$VALUE
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
sudo apt install -y containerd.io
sudo su root -c "mkdir -p /etc/containerd"
sudo su root -c "containerd config default>/etc/containerd/config.toml"
sudo systemctl restart containerd
sudo systemctl enable containerd
# systemctl status  containerd
sudo su root -c "sed -i -e 's/systemd_cgroup = false/systemd_cgroup = true/g' /etc/containerd/config.toml"
if [[ "${role}" -ne "master" ]]; then
    echo -e "==============================================================="
    echo -e "Successfully Installed k8s ${role} node with containerd as container runtime"
    echo -e "==============================================================="
    exit 1
else
    lsmod | grep br_netfilter
    sudo systemctl enable kubelet
    sudo kubeadm config images pull --cri-socket ${sock}
fi