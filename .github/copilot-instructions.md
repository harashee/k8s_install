<!--
Purpose: Short, actionable guidance for AI coding agents working on this repository.
Keep entries tight, reference concrete files and examples, and don't suggest
non-discoverable project practices.
-->
# Copilot / AI Agent Instructions

**Purpose:** Help an AI coding agent be productive in this repo by describing
the project layout, the execution model for installer scripts, and concrete
examples to follow when modifying or adding files.

**Quick repo layout:**
- `k8s_install/`: main installer and helper scripts for Ubuntu 20.04 Kubernetes installs.
  - `k8s_installer.sh`: entry-point wrapper that sources `k8s_config.cfg` and invokes CRI scripts.
  - `k8s_config.cfg`: maps container runtimes and CNI YAML URLs to shell variables.
  - `docker.sh`, `containerd.sh`, `crio.sh`: CRI-specific install scripts called by `k8s_installer.sh`.
- `Python/`, `Zayd/`: small, standalone Python utilities (not a packaged module).

**Big picture:**
- This project is a set of bash installer scripts intended to run on Ubuntu 20.04.
- `k8s_installer.sh` parses four flags (`--ver`, `--cri`, `--net`, `--role`) and then
  delegates runtime installation to `./{cri}.sh` using an indirect expansion of variables
  defined in `k8s_config.cfg` (e.g. `${!cri}` and `${!net}`). Keep any change compatible
  with this indirect-variable pattern.

**Concrete examples & patterns to follow**
- Argument parsing: scripts use a minimal `while` + `case` pattern and `awk -F=` to split
  args (see `k8s_installer.sh` and `docker.sh`). When adding flags, use the same style.
- Config usage: `k8s_config.cfg` is `source`d by `k8s_installer.sh`. It contains shell
  assignments (e.g. `containerd="/run/containerd/containerd.sock"`) — modify it only when
  you intend to change the mapping between names and URIs/sockets.
- Calling CRI scripts: `k8s_installer.sh` runs `sudo ./${cri}.sh --sock=${!cri} --role=${role}`.
  New code must preserve this calling convention or update both the caller and targets.

**How to run (discovered examples):**
- Master install example (from `k8s_install/README.md`):
```
./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=master
```
- CRI scripts expect `--sock` and `--role`, e.g. `./containerd.sh --sock=/run/containerd/containerd.sock --role=master`.

**Environment assumptions (do not change without verification):**
- Target OS: Ubuntu 20.04 (scripts install apt packages and use Ubuntu package repos).
- Many commands require `sudo` and assume systemctl-managed services.

**What an AI agent should not do (unless user asks):**
- Rework the arg-parsing style across scripts or change config variable names without
  updating every call site.
- Assume tests or CI exist—none are present; propose adding tests before creating them.

**Guidance for edits & PRs:**
- When modifying installer flow, include a short runnable example in the PR description
  (the exact `./k8s_installer.sh ...` command you used) and confirm which Ubuntu release
  you tested on.
- For code changes touching `k8s_config.cfg`, include before/after examples of variable values
  and update any script that uses indirect expansions (`${!var}`).

**Files to inspect when making changes:**
- `k8s_install/k8s_installer.sh` — main entry point and best source of workflow logic.
- `k8s_install/k8s_config.cfg` — runtime sockets and CNI URLs.
- `k8s_install/{docker,containerd,crio}.sh` — CRI-specific steps and `kubeadm config images pull` usage.

If anything in this file is unclear or you'd like examples expanded (e.g. typical failure
modes from running the installer, or a small test harness), say which area and I'll add it.

**Failure modes & quick remediation**
- `kubeadm init` fails due to image pull/network: verify `kubeadm config images pull --cri-socket ${sock}` was run
  in the CRI script and that the host has internet access. Check output of `sudo journalctl -u kubelet -n 200`.
- `swap` not disabled: scripts attempt `sudo swapoff -a` and comment out `/etc/fstab`, but some images
  may still fail. Confirm `sudo swapon --show` returns nothing and `/etc/fstab` entries are commented.
- CNI not applied / pods stuck: ensure CNI YAML URL in `k8s_config.cfg` is reachable and that `kubectl apply -f ${!net}` succeeded.
  Use `kubectl get pods -A` to inspect CNI pod statuses.
- CRI socket mismatch: `k8s_config.cfg` maps names to sockets. If the installer passes the wrong socket,
  `kubeadm` image pulls or kubelet may fail. Verify `${!cri}` resolves to an existing socket (e.g. `ls -l /run/containerd/containerd.sock`).

**Quick verification checklist (run after installer completes on master)**
- Confirm kubelet and CRI services are running:
```
sudo systemctl status kubelet
sudo systemctl status containerd   # or docker / crio depending on CRI
```
- Confirm cluster control plane and nodes:
```
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```
- Confirm CNI applied and pods are `Running` or `Completed` (not `CrashLoopBackOff`/`ImagePullBackOff`).

**PR checklist for changes to installer scripts**
- Include the exact command used to reproduce the run (e.g. `./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=master`).
- If changing `k8s_config.cfg`, list before/after values and update any dependent scripts that use `${!var}`.
- If adding flags, mirror the existing `while` + `case` pattern and update `display_usage()` in all affected scripts.
- Document which Ubuntu release you tested on and include `systemctl` outputs or logs for failures you addressed.

**Optional: Local testing sandbox**
- You can test argument parsing and basic flow on a non-Ubuntu machine by running the scripts with `--role=worker`
  and verifying they exit early after installing the runtime (they often return after non-master install). Example:
```
./k8s_installer.sh --ver=1.22 --cri=containerd --net=calico --role=worker
```
- Do not run the full master path unless on a disposable Ubuntu 20.04 VM or container with proper privileges.

If you'd like, I can add a short `verify.sh` helper that runs the verification checklist automatically — tell me and
I'll add it to the repo.

**Repository verification helper**
- A small helper script `k8s_install/verify.sh` exists to run the quick verification checklist
  described above. It checks `kubelet`, the detected CRI service, CRI sockets (from `k8s_config.cfg`),
  whether swap is disabled, basic `kubectl` outputs, and reachability of CNI URLs.
- Run examples:
```
cd k8s_install
sudo bash verify.sh
sudo bash verify.sh --cri containerd
```
- The script is safe to run on worker nodes and will exit early for non-master flows; run full master
  verification only on disposable VMs or systems you control.
