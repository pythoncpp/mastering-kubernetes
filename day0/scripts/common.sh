set -euxo pipefail

# declare variables
KUBERNETES_VERSION="v1.31"
CRIO_VERSION="v1.30"

# disable swap
sudo swapoff -a

# Create the .conf file to load the modules at boot time
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install CRI-O Runtime
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

# add CRI-O key and repository
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    sudo tee /etc/apt/sources.list.d/cri-o.list

# update the cache and install CRI-O
sudo apt-get update -y
sudo apt-get install -y cri-o

# start the CRI-O service
sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service

# add the kubernetes key and repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    sudo tee /etc/apt/sources.list.d/kubernetes.list

# install kubelet, kubeadm, and kubectl latest version
sudo apt-get update -y
sudo apt-get install -y kubelet kubectl kubeadm

# Prevent automatic updates for kubelet, kubeadm, and kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo apt-get update -y
