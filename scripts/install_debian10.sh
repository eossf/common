#!/bin/bash

ns=$1
port=$2
if [[ $port == "" ]] ; then
	echo "2 parameters needed => namespace port"
	exit;
fi

apt -y update
apt -y upgrade

# nslookup netstats ...
apt -y install ntp jq dnsutils net-tools

# go
../go/install_go.sh

# docker
../BUILD/install_docker.sh

# kubernetes
../kub/install_kubectl.sh

# helm 3
../helm/install_helm.sh

# AWS cli
#../aws/install_aws.sh

# k3d/k3s
../k3d/install_k3d.sh $ns

# create the cluster
../k3d/create_k3d.sh $ns $port

# OpenEBS for PV/PVC
../openebs/install_openebs.sh

# argoCD
#argocd/install_argocd.sh

exit;
