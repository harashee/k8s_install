# kubernetes Installation
This script will help you install Kubernetes with different k8s versions, CNIs and Container runtime on Ubuntu 20.04

I will be adding more CNIs in future.

# Requirement

```
Operating System - Ubuntu 20.04
Node Requirement (Master/Worker) - 4 GB RAM and 2 CPUs
```

# Example usage:

Run the below command on the master node

```
./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=master
```
Command line supported arguments

--ver ==> Kubernetes Version

--cri ==> containerd / cri-o / docker

--net ==> calico / flannel / weavenet

--role ==> master / worker

Run the below command on the worker nodes

```
./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=worker
```

# Joining Worker node to K8s Cluster

Get the "kubeadm join" from the master node installation logs. Looks like below.

```
kubeadm join --discovery-token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234..cdef 1.2.3.4:6443
```

Run the command like above got from the master node in the worker node. You should able to see worker node is in ready state when run the below command in master node.


```
$ kubectl get nodes
NAME            STATUS   ROLES    AGE    VERSION
master          Ready    <none>   411d   v1.22.2
worker1         Ready    <none>   411d   v1.22.2
```