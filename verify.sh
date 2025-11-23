#!/usr/bin/env bash
# Lightweight verification helper for the k8s_install scripts.
# Usage: sudo ./verify.sh [--cri containerd|docker|crio]

set -o pipefail

ROOT_CHECK() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "NOTE: some checks use sudo — you may be prompted for a password."
  fi
}

source k8s_config.cfg 2>/dev/null || true

CRI_OVERRIDE=""
if [ "$1" = "--cri" ] && [ -n "$2" ]; then
  CRI_OVERRIDE="$2"
fi

detect_cri() {
  if [ -n "$CRI_OVERRIDE" ]; then
    echo "$CRI_OVERRIDE"
    return
  fi
  if [ -S "${containerd:-/run/containerd/containerd.sock}" ] || systemctl list-units --type=service | grep -q containerd; then
    echo "containerd"
    return
  fi
  if [ -S "${docker:-/var/run/docker.sock}" ] || systemctl list-units --type=service | grep -q docker; then
    echo "docker"
    return
  fi
  if [ -S "${crio:-/var/run/crio/crio.sock}" ] || systemctl list-units --type=service | grep -q crio; then
    echo "crio"
    return
  fi
  echo "unknown"
}

check_service() {
  svc=$1
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    if systemctl is-active --quiet "$svc"; then
      echo "OK: service $svc is active"
    else
      echo "WARN: service $svc is not active -- run: sudo systemctl status $svc"
    fi
  else
    echo "INFO: service $svc not installed or unit file not present"
  fi
}

check_socket() {
  sock=$1
  if [ -S "$sock" ]; then
    echo "OK: socket $sock exists"
  else
    echo "WARN: socket $sock not found"
  fi
}

check_swap() {
  if command -v swapon >/dev/null 2>&1; then
    if swapon --noheadings | grep -q .; then
      echo "WARN: swap is enabled — kubeadm requires swapoff. Run: sudo swapoff -a and comment /etc/fstab entries"
    else
      echo "OK: swap is disabled"
    fi
  else
    echo "INFO: swapon command not available to check swap status"
  fi
}

check_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    echo "OK: kubectl present — showing basic cluster info (may fail if kubeconfig not set)"
    kubectl cluster-info 2>&1 | sed -n '1,5p'
    echo "--- kubectl get nodes ---"
    kubectl get nodes -o wide 2>&1 | sed -n '1,10p'
  else
    echo "WARN: kubectl not found in PATH"
  fi
}

check_cni_urls() {
  for name in calico flannel weavenet multus; do
    url=$(eval echo \${$name})
    if [ -n "$url" ]; then
      echo "Checking CNI $name -> $url"
      if command -v curl >/dev/null 2>&1; then
        if curl -fsS --head "$url" >/dev/null 2>&1; then
          echo "OK: $name URL reachable"
        else
          echo "WARN: $name URL not reachable with curl"
        fi
      else
        echo "INFO: curl not installed; cannot test $name URL"
      fi
    fi
  done
}

main() {
  ROOT_CHECK
  echo "Starting verification checks for this repository (k8s_install)"
  echo

  cri=$(detect_cri)
  echo "Detected CRI: $cri"
  echo

  # Services
  check_service kubelet
  case "$cri" in
    containerd)
      check_service containerd
      check_socket "${containerd:-/run/containerd/containerd.sock}"
      ;;
    docker)
      check_service docker
      check_socket "${docker:-/var/run/docker.sock}"
      ;;
    crio)
      check_service crio
      check_socket "${crio:-/var/run/crio/crio.sock}"
      ;;
    *)
      echo "INFO: CRI unknown; checking common sockets"
      check_socket "${containerd:-/run/containerd/containerd.sock}"
      check_socket "${docker:-/var/run/docker.sock}"
      check_socket "${crio:-/var/run/crio/crio.sock}"
      ;;
  esac

  echo
  check_swap
  echo
  check_kubectl
  echo
  check_cni_urls

  echo
  echo "Verification complete. Review any WARN lines above and follow remediation steps in .github/copilot-instructions.md"
}

main "$@"
