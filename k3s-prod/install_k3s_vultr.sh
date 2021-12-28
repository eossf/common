#!/bin/bash

# default value
$DEFAULTNODELIST = "MASTER01 MASTER02 MASTER03 NODE01 NODE02 NODE03"
UBUNTU="517"
CENTOS="362"
plan_master="vc2-2c-4gb"
plan_node="vc2-1c-2gb"
osid="$UBUNTU"
region="cdg"

nodelist="$1"
vultrapikey="$2"
k3stoken="$3"
if [[ $nodelist == "" ]] ; then
	nodelist=$DEFAULTNODELIST
fi
if [[ $vultrapikey == "" ]] ; then
	vultrapikey=`env | grep "VULTR_API_KEY" | cut -d"=" -f2`
  if [[ $vultrapikey == "" ]] ; then
    echo "Please enter the VULTR_API_KEY parameter or exported env var"
    exit;
  fi
fi
if [[ $k3stoken == "" ]] ; then
	k3stoken=`env | grep "K3S_TOKEN" | cut -d"=" -f2`
  if [[ $k3stoken == "" ]] ; then
    echo "Please enter the K3S_TOKEN parameter or exported env var"
    exit;
  fi
fi
VULTR_API_KEY=$vultrapikey
K3S_TOKEN=$k3stoken

function valid_ip()
{
    local  ip=$1
    local  stat=1
    if [[ $NODE_MAIN_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($NODE_MAIN_IP)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

echo "Get private network list"
APN=`curl -s "https://api.vultr.com/v2/private-networks" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.networks[].id' | tr -d '"'`

if [[ $APN == "" ]]; then 
    echo "Create one private network"
    APN=`curl -s "https://api.vultr.com/v2/private-networks" \
    -X POST \
    -H "Authorization: Bearer ${VULTR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
        "region" : "'$region'",
        "description" : "K3s Private Network",
        "v4_subnet" : "192.168.0.0",
        "v4_subnet_mask" : 16
    }' | jq '.network.id' | tr -d '"'`
fi

echo "Get SSH key for accessing servers"
SSHKEY_ID=`curl -s "https://api.vultr.com/v2/ssh-keys"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.ssh_keys[].id' | tr -d '"'`

echo "Create masters and workers"
for node in $nodelist
do
  if [[ ${node} =~ "MASTER" ]]; then
    plan=$plan_master
  else
    plan=$plan_node
  fi
DATA='{"region":"'$region'",
"plan":"'$plan'",
"label":"'$node'",
"hostname":"'$node'",
"os_id":'$osid',
"attach_private_network":["'$APN'"],
"sshkey_id":["'$SSHKEY_ID'"]
}'

  echo "Create node:"$node
  curl -s "https://api.vultr.com/v2/instances" -X POST -H "Authorization: Bearer ${VULTR_API_KEY}" -H "Content-Type: application/json" --data "${DATA}"
  echo
done

echo "Wait provisionning finishes ..."
sleep 90
echo

echo "Get Nodes and set internal interface "
NODES=`curl -s "https://api.vultr.com/v2/instances" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
NODES_COUNT=`echo $NODES | jq '.instances' | grep -i '"id"' | tr -d "," | cut -d ":" -f2 | tr -d " " | tr -d '"'`
for t in ${NODES_COUNT[@]}; do
  NODE=`curl -s "https://api.vultr.com/v2/instances/${t}" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
  NODE_LABEL=`echo $NODE | jq '.instance.label' | tr -d '"'`
  if [[ $NODE_LABEL =~ "MASTER" || $NODE_LABEL =~ "NODE" ]]; then
    NODE_INTERNAL_IP=`echo $NODE | jq '.instance.internal_ip' | tr -d '"'`
    NODE_MAIN_IP=`echo $NODE | jq '.instance.main_ip' | tr -d '"'`

    if [[ $osid == "$CENTOS" ]]; then
      echo "CentOS 8 Linux detected"
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "nmcli | grep 'disconnected' | cut -d':' -f1 > /tmp/ITF"
      scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP":/tmp/ITF /tmp/ITF
      ITF=`cat /tmp/ITF`
      rm /tmp/ITF
      echo "Capture itf name :"$ITF
      cp -f ifcfg.tmpl ifcfg-$ITF
      echo ${NODE_LABEL}" ip="$NODE_MAIN_IP" setup private interface "${NODE_INTERNAL_IP}
      sed -i 's/#IPV4#/'${NODE_INTERNAL_IP}'/g' ifcfg-$ITF
      sed -i 's/#ITF#/'$ITF'/g' ifcfg-$ITF
      scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" ./ifcfg-$ITF root@"$NODE_MAIN_IP":/etc/sysconfig/network-scripts/ifcfg-$ITF
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "nmcli con load /etc/sysconfig/network-scripts/ifcfg-"$ITF
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "nmcli con up 'System "$ITF"'" 
      fi
    if [[ $osid == "$UBUNTU" ]]; then
      echo "Ubuntu 20.10 Linux detected"
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "ip a | grep -iA2 '3: enp' | grep -i 'link/ether' | cut -d' ' -f6 > /tmp/MAC"
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "ip a | grep -i '3: enp' | cut -d':' -f2 | tr -d ' ' > /tmp/ITF"
      scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP":/tmp/MAC /tmp/MAC
      scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP":/tmp/ITF /tmp/ITF
      MAC=`cat /tmp/MAC`
      rm /tmp/MAC
      ITF=`cat /tmp/ITF`
      rm /tmp/ITF
      echo "Capture itf name :"$ITF
      cp -f netplan.tmpl 10-$ITF.yaml
      echo ${NODE_LABEL}" ip="$NODE_MAIN_IP" setup private interface "${NODE_INTERNAL_IP}
      sed -i 's/#IPV4#/'${NODE_INTERNAL_IP}'/g' 10-$ITF.yaml
      sed -i 's/#ITF#/'$ITF'/g' 10-$ITF.yaml
      sed -i 's/#MAC#/'$MAC'/g' 10-$ITF.yaml
      scp -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" ./10-$ITF.yaml root@"$NODE_MAIN_IP":/etc/netplan/10-$ITF.yaml
      ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"$NODE_MAIN_IP" "netplan apply" 
    fi
  fi
done

# wait
sleep 2

function parse_node_searched()
{
  local searched=$1
  local i=0
  for t in ${NODES_COUNT[@]}; do
    
    NODE=`curl -s "https://api.vultr.com/v2/instances/${t}" -X GET -H "Authorization: Bearer ${VULTR_API_KEY}" | jq '.'`
    NODE_LABEL=`echo $NODE | jq '.instance.label' | tr -d '"'`
    echo "Node "$NODE_LABEL" found"
    if [[ $NODE_LABEL == "$searched" ]]; then
      echo $searched" is the node searched"
      NODE_INTERNAL_IP=`echo $NODE | jq '.instance.internal_ip' | tr -d '"'`
      NODE_MAIN_IP=`echo $NODE | jq '.instance.main_ip' | tr -d '"'`
      node_returned[$((i++))]+=$NODE_INTERNAL_IP
      node_returned[$((i++))]+=$NODE_MAIN_IP
      break
    fi
  done
}

echo "start cluster K3s - init cluster"
declare -a node_returned

echo " ------------------------------------------- "
searched="MASTER01"
echo $searched
echo " ------------------------------------------- "
node_returned=()
parse_node_searched $searched
IPMASTER=""
if [[ "${node_returned[@]}" == "" ]]; then
    echo "Error no "$searched" node found"
    exit
else
  IPMASTER=${node_returned[0]}
  # cluster init MASTER01
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sfL https://get.k3s.io | K3S_TOKEN='"$K3S_TOKEN"' INSTALL_K3S_EXEC='--disable traefik --cluster-init --cluster-cidr=192.168.120.0/21' sh -s -"
fi

echo " ------------------------------------------- "
searched="MASTER02"
echo $searched
echo " ------------------------------------------- "
node_returned=()
parse_node_searched $searched
if [[ "${node_returned[@]}" == "" ]]; then
    echo "Error no "$searched" node found"
else
  # join cluster
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sk https://"$IPMASTER":6443/cacerts -o /usr/local/share/ca-certificates/k3s.crt"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "update-ca-certificates"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sfL https://get.k3s.io | K3S_TOKEN='"$K3S_TOKEN"' INSTALL_K3S_EXEC='--disable traefik --server https://"$IPMASTER":6443' sh -s -"
fi

echo " ------------------------------------------- "
searched="MASTER03"
echo $searched
echo " ------------------------------------------- "
node_returned=()
parse_node_searched $searched
if [[ "${node_returned[@]}" == "" ]]; then
    echo "Error no "$searched" node found"
else
  # join cluster
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sk https://"$IPMASTER":6443/cacerts -o /usr/local/share/ca-certificates/k3s.crt"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "update-ca-certificates"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sfL https://get.k3s.io | K3S_TOKEN='"$K3S_TOKEN"' INSTALL_K3S_EXEC='--disable traefik --server https://"$IPMASTER":6443' sh -s -"
fi

echo " ------------------------------------------- "
searched="NODE01"
echo $searched
echo " ------------------------------------------- "
node_returned=()
parse_node_searched $searched
if [[ "${node_returned[@]}" == "" ]]; then
    echo "Error no "$searched" node found"
else
  # join cluster
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sk https://"$IPMASTER":6443/cacerts -o /usr/local/share/ca-certificates/k3s.crt"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "update-ca-certificates"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sfL https://get.k3s.io | K3S_TOKEN='"$K3S_TOKEN"' K3S_URL='https://"$IPMASTER":6443' sh -s -"
 fi

echo " ------------------------------------------- "
searched="NODE02"
echo $searched
echo " ------------------------------------------- "
node_returned=()
parse_node_searched $searched
if [[ "${node_returned[@]}" == "" ]]; then
    echo "Error no "$searched" node found"
else
  # join cluster
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sk https://"$IPMASTER":6443/cacerts -o /usr/local/share/ca-certificates/k3s.crt"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "update-ca-certificates"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sfL https://get.k3s.io | K3S_TOKEN='"$K3S_TOKEN"' K3S_URL='https://"$IPMASTER":6443' sh -s -"
fi

echo " ------------------------------------------- "
searched="NODE03"
echo $searched
echo " ------------------------------------------- "
node_returned=()
parse_node_searched $searched
if [[ "${node_returned[@]}" == "" ]]; then
    echo "Error no "$searched" node found"
else
  # join cluster
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sk https://"$IPMASTER":6443/cacerts -o /usr/local/share/ca-certificates/k3s.crt"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "update-ca-certificates"
  ssh -i ~/.ssh/id_rsa -o "StrictHostKeyChecking=no" root@"${node_returned[1]}" "curl -sfL https://get.k3s.io | K3S_TOKEN='"$K3S_TOKEN"' K3S_URL='https://"$IPMASTER":6443' sh -s -"
fi
