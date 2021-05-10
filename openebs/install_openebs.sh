#!/bin/bash

# OpenEBS for PV/PVC 
# install https://docs.openebs.io/docs/next/uglocalpv-hostpath.html
apt-get install -y open-iscsi
systemctl enable iscsid
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml