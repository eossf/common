#!/bin/bash

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 775 get_helm.sh
./get_helm.sh
