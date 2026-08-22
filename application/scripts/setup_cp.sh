#!/bin/bash
control_plane_hostname="$1"

if [ -z "$control_plane_hostname" ]; then
    echo "Control-plane hostname is required."
    exit 1
fi

if ! sudo kubeadm init --control-plane-endpoint "$control_plane_hostname" --upload-certs; then
    echo "Control-plane initialization failed."
    exit 1
fi

mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

#install helm
if ! curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4; then
    echo "Helm download failed. Exiting."
    exit 1
fi
chmod 700 get_helm.sh
if ! sudo ./get_helm.sh; then
    echo "Helm installation failed. Exiting."
    exit 1
fi
rm -f get_helm.sh
if helm version; then
    echo "Helm is installed"
else
    echo "Helm installation failed"
    exit 1
fi
#install cilium as the CNI plugin
if ! helm upgrade --install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.20.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$control_plane_hostname" \
  --set k8sServicePort=6443 \
  --set ipam.mode=cluster-pool \
    --set ipam.operator.clusterPoolIPv4PodCIDRList[0]=192.168.0.0/16; then
        echo "Cilium installation failed."
        exit 1
fi