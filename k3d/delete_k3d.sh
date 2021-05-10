#!/bin/bash

ns=$1
if [[ $ns == "" ]] ; then
	echo "set a namespace"
	exit;
fi

kubectl config delete-cluster k3d-$ns
kubectl config delete-context k3d-$ns
kubectl config unset users.$ns
k3d cluster delete $ns
k3d registry delete k3d-local-registry

# docker regitry unsecure 
rm /etc/docker/daemon.json
