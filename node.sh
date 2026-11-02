# --- base update ---
sudo dnf update -y

# --- container runtime ---
# Note: kubeadm 1.30 needs a CRI runtime. On Ubuntu "docker.io" pulls in
# containerd automatically; on Amazon Linux install containerd directly.
sudo dnf install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl enable --now containerd

# --- optional: docker CLI too (NOT the k8s runtime) ---
# sudo dnf install -y docker
# sudo systemctl enable --now docker
# sudo usermod -aG docker ec2-user      # better than chmod 666 on the socket
# newgrp docker

# --- swap off (AL2023 usually has none, but make sure) ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- kernel modules ---
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# --- sysctl for the bridge/forwarding ---
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# --- SELinux to permissive (Ubuntu has no equivalent step) ---
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# --- kubernetes rpm repo (replaces the apt keyring + sources.list block) ---
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# --- install pinned 1.30.0 ---
sudo dnf install -y kubelet-1.30.0 kubeadm-1.30.0 kubectl-1.30.0 \
  --disableexcludes=kubernetes

sudo systemctl enable --now kubelet
