# kubernetes Installation
This script will help you install Kubernetes with different k8s versions, CNIs and Container runtime on Ubuntu 20.04

I will be adding more CNIs in future.

# Requirement

```
Operatig System - Ubuntu 20.04
Node Requiremt (Master/Worker) - 4 GB and 2 CPU

```

# Example usage:

```
./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=master

```

--ver ==> Kubernetes Version

--cri ==> containerd / cri-o / docker

--net ==> calico / flannel / weavenet

--role ==> master / worker
