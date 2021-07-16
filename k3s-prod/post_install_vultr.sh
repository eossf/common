#!/bin/bash

vultrapikey="$1"
if [[ $vultrapikey == "" ]] ; then
	vultrapikey=`env | grep "VULTR_API_KEY" | cut -d"=" -f2`
  if [[ $vultrapikey == "" ]] ; then
    echo "Please enter the VULTR_API_KEY parameter or exported env var"
    exit;
  fi
fi
VULTR_API_KEY=$vultrapikey

function parse_node()
{
  for t in ${NODES_COUNT[@]}; do
    NODE=`curl -s "https://api.vultr.com/v2/instances/${t}" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
    NODE_LABEL=`echo $NODE | jq '.instance.label' | tr -d '"'`
    echo "Node "$NODE_LABEL" found"
    NODE_MAIN_IP=`echo $NODE | jq '.instance.main_ip' | tr -d '"'`
    if [[ $NODE_LABEL =~ "MASTER" ]]; then
      echo "Apply post-install to node: "$NODE_LABEL
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" <<EOF
if [[ `cat ~/.bashrc | grep -i "k='kubectl'" | wc -l` == 0 ]]; then
 echo "alias k='kubectl'" >> .bashrc
 echo "export PATH=~/.krew/bin:$PATH" >> .bashrc
fi
source .bashrc
kubectl label node node01 nodetype=node
kubectl label node node02 nodetype=node
kubectl label node node03 nodetype=node
kubectl create ns mlops
kubectl config set-context $(kubectl config current-context) --namespace=mlops

apt -y update
apt -y upgrade

# nslookup netstats ...
apt -y install ntp jq dnsutils net-tools

git clone https://github.com/eossf/common

# go
common/go/install_go.sh
common/openebs/install_openebs.sh
common/helm/install_helm.sh
common/krew/install_krew.sh

EOF
else
      echo "Apply post-install to node: "$NODE_LABEL
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" <<EOF
apt -y update
apt -y upgrade

# nslookup netstats ...
apt -y install ntp jq dnsutils net-tools
EOF
    fi
  done
}

echo "Get nodes and post install"
NODES=`curl -s "https://api.vultr.com/v2/instances" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
NODES_COUNT=`echo $NODES | jq '.instances' | grep -i '"id"' | tr -d "," | cut -d ":" -f2 | tr -d " " | tr -d '"'`

parse_node