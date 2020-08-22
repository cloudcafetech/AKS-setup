#!/bin/bash
# Monitoring & logging setup script in AKS with Windows container 

# Download for monitoring and logging

wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/kubelog.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/loki.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/loki-ds.json
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/loki-win-ds.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/kubemon.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/pod-monitoring.json

# Deploy for monitoring and logging

kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
kubectl create ns logging
kubectl create secret generic loki -n logging --from-file=loki.yaml
kubectl create -f kubelog.yaml -n logging
kubectl create -f loki-win-ds.yaml -n logging

## Upload Grafana dashboard & loki datasource

HIP=52.158.47.53
curl -vvv http://admin:admin2675@$HIP/api/dashboards/db -X POST -d @pod-monitoring.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP/api/dashboards/db -X POST -d @cluster-cost.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP/api/datasources -X POST -d @loki-ds.json -H 'Content-Type: application/json' 
