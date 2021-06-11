# Install production ready K3S Cluster

CentOS8 installation
echo "VLAN: 10.24.96/24"

## setup public itf
````bash
nmcli dev show | grep "GENERAL.DEVICE" | while read -r line ; do
eth=`echo $line | cut -d" " -f2`
ip=`ip -o -4 addr list $eth | awk '{print $4}' | cut -d/ -f1`
echo "$eth IP="$ip":"
if [[ $ip = "" ]] || [[ $ip =~ ^10\.24\.96\. ]]; then
    echo "SET ip private "$INC
    cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$eth
# Private network: net60c223f37da25
TYPE="Ethernet"
DEVICE=$eth
ONBOOT="yes"
BOOTPROTO="none"
IPADDR=10.24.96.$INC
PREFIX=20
MTU=1450
EOF
    ip=""
    fi
    if [[ $ip = "127.0.0.1" ]]; then
        ip=""
    fi
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "SET ip public"
        gw="`echo $ip | cut -d"." -f1-3`.1"
        echo "gw:$gw"
        cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$eth
TYPE="Ethernet"
DEVICE=$eth
ONBOOT="yes"
BOOTPROTO="none"
IPADDR=$ip
PREFIX=23
GATEWAY=$gw
DNS1=$DNS
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
EOF
    fi
done
````

Then relaunch Network

````bash
nmcli con load /etc/sysconfig/network-scripts/ifcfg-enp1s0 
nmcli con up 'System enp1s0'

nmcli con load /etc/sysconfig/network-scripts/ifcfg-enp6s0
nmcli con up 'System enp6s0'
````