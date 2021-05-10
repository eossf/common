#!/bin/bash

ns=$1
port=$2
if [[ $port == "" ]] ; then
	echo "set a namespace and an external port"
	exit;
fi

eth=`ip r | head -n 1 | cut -d' ' -f5`
echo "Interface detected : "$eth

# CREATE REGISTRY
k3d registry create local-registry --port $port

# CREATE K3D CLUSTER 
k3d cluster create $ns --registry-use k3d-local-registry:$port

echo " *** Docker Registry on "$eth" *** "
echo
ip=`ip -o -4 addr list $eth | awk '{print $4}' | cut -d/ -f1`
fqdn=`dig -x $ip | grep -E "\b([0-9]{1,3}\.){3}[0-9]{1,3}\.in-addr.arpa\b" | head -n 2 | awk '{print $5}' | sed 's/.$//'`
tmp=`docker ps --format '{{.Image}} {{.Ports}}' | grep "registry" | cut -d":" -f3`
regport=`echo $tmp | cut -d"-" -f1`
containerregport=`echo $tmp | cut -d"-" -f2 | sed 's/^>//' | sed 's/\/tcp//'`
echo
echo "Ethernet device : "$eth
echo "IP              : "$ip
echo "FQDN            :"$fqdn
echo "Port registry   : "$regport
echo "Local Port      : "$containerregport
echo
echo " for pushing, pulling, using images in kubectl:"
echo
echo "docker pull alpine"
echo "docker tag alpine localhost:$regport/my-alpine"
echo "docker push localhost:$regport/my-alpine"
echo "kubectl run my-alpine --image k3d-$ns-registry:$regport/my-alpine"

# KUBECONFIG
# !!! NOTICE THE k3d- prefix !!!
# warning if you reload the same cluster, remove the config (or clean the entry) rm ~/.kube/config
k3d kubeconfig get $ns >> ~/.kube/config
export KUBECONFIG=~/.kube/config
kubectl config use-context k3d-$ns
kubectl create ns $ns

# docker regitry unsecure 
echo '{"insecure-registries":["k3d-local-registry:'$regport'", "localhost:'$regport'"] }' > /etc/docker/daemon.json
