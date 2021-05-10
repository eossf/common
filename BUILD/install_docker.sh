#!/bin/bash

# docker 
aptitude -y  install apt-transport-https ca-certificates gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
apt-key fingerprint 0EBFCD88

# normal command
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

# IN CASE ISSUE with DNS. I temporary replaced by d2h67oheeuigaw.cloudfront.net
# after nslookup download.docker.com
#add-apt-repository \
#   "deb [arch=amd64] https://d2h67oheeuigaw.cloudfront.net/linux/debian \
#   $(lsb_release -cs) \
#   stable"
# verify your /etc/apt/sources.list and comment download.docker.com

aptitude -y update
aptitude -y  install docker-ce docker-ce-cli containerd.io unzip
