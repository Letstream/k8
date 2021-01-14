#!/bin/bash

# This scripts prepares the node to join the kubernetes cluster by installing dependecies and configuring firewall.
# Replace the kubeadm join command to that of your kubernetes cluster

# Prepare Node
apt update && apt upgrade -y

# Install Dependencies
apt -y install tmux curl git vim apt-transport-https curl gnupg2 software-properties-common ca-certificates

# Add Kubernetes GPG
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Add Kubernetes Repo
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Trigger Cache Refresh
apt update

# Install Kubernetes essentials
apt -y install wget kubelet kubeadm kubectl

# Disable Auto Update
apt-mark hold kubelet kubeadm kubectl

# Disable SWAP
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

# Other Network Config
modprobe overlay
modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y containerd.io docker-ce docker-ce-cli
mkdir -p /etc/systemd/system/docker.service.d
tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Enable Kubelet to autostart
systemctl enable kubelet

# Add Kubernetes Master Domain
echo "<master_node_ip> k8s-cluster.local" >> /etc/hosts

# Configure Firewall
ufw allow ssh
ufw allow 10250/tcp
ufw allow 10251/tcp
ufw allow 10255/tcp
ufw allow http
ufw allow https
ufw enable
ufw reload

# Install support for nfs
apt install nfs-common

# Add Ubuntu User
adduser --disabled-password --gecos "" ubuntu
usermod -aG sudo ubuntu

kubeadm join <master_node_ip>:6443 --token <your_join_token> --discovery-token-ca-cert-hash sha256:<your_join_discovery_token>
