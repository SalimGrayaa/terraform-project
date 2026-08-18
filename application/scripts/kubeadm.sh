#!/bin/bash
sudo swapoff -a
sudo apt update
sudo apt install -y containerd
sudo apt install -y apt-transport-https ca-certificates curl gpg
sudo apt-mark hold kubelet kubeadm kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
if kubeadm version &> /dev/null; then
    echo "kubeadm is installed"
else
    echo "kubeadm installation failed"
    exit 1
fi
if kubectl version &> /dev/null; then
    echo "kubectl is installed"
else
    echo "kubectl installation failed"
    exit 1
fi
if kubelet --version &> /dev/null; then
    echo "kubelet is installed"
else
    echo "kubelet installation failed"
    exit 1
fi

