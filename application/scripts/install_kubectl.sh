#!/bin/bash
sudo swapoff -a
sudo apt-get update
sudo apt-get install -y containerd
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
sudo apt-mark hold kubelet kubeadm kubectl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
if kubeadm version &> /dev/null; then
    echo "kubeadm is installed"
else
    echo "kubeadm installation failed"
    exit 1
fi
if [ -x /usr/bin/kubectl ]; then
    echo "kubectl is installed"
else
    echo "kubectl installation failed"
    exit 1
fi
if systemctl is-active --quiet kubelet; then
    echo "kubelet service is running"
else
    echo "kubelet service not running, attempting to start..."
    sudo systemctl restart kubelet
fi
