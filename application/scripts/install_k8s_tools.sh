#!/bin/bash

set -e

# Disable swap
sudo swapoff -a

# Load required Kubernetes kernel modules
sudo tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure Kubernetes networking
sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Install containerd
sudo apt-get update
sudo apt-get install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Use systemd as the cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Enable and restart containerd
sudo systemctl enable containerd
sudo systemctl restart containerd

# Install crictl
VERSION="v1.36.0"
temporary_directory=$(mktemp -d)

curl -fsSL --retry 3 \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/${VERSION}/crictl-${VERSION}-linux-amd64.tar.gz" \
    --output "${temporary_directory}/crictl.tar.gz"

sudo tar -xzf "${temporary_directory}/crictl.tar.gz" -C /usr/local/bin
rm -rf "${temporary_directory}"

# Configure crictl to use containerd
sudo tee /etc/crictl.yaml > /dev/null <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Install Kubernetes dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings

# Add Kubernetes repository
curl -fsSL \
    https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key |
    sudo gpg --dearmor --yes \
    -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' |
    sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# Install Kubernetes components
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
sudo systemctl enable --now kubelet

# Verify kubeadm
if kubeadm version &> /dev/null; then
    echo "kubeadm is installed"
else
    echo "kubeadm installation failed"
    exit 1
fi

# Verify kubectl
if [ -x /usr/bin/kubectl ]; then
    echo "kubectl is installed"
else
    echo "kubectl installation failed"
    exit 1
fi

# Verify kubelet
if systemctl is-active --quiet kubelet; then
    echo "kubelet service is running"
else
    echo "kubelet service not running, attempting to start..."
    sudo systemctl restart kubelet
fi

# Verify containerd
if systemctl is-active --quiet containerd; then
    echo "containerd service is running"
else
    echo "containerd service is not running"
    exit 1
fi

# Verify CRI
if sudo crictl info &> /dev/null; then
    echo "CRI runtime is configured correctly"
else
    echo "CRI runtime configuration failed"
    exit 1
fi

echo "Kubernetes prerequisites installation completed successfully."