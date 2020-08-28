#!/bin/bash
# Monitoring & logging setup script in AKS with Windows container

# Download for monitoring and logging

wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/kubelog.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/loki.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/loki-ds.json
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/linux-prometheus-configmap.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/kubemon.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/pod-monitoring.json
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/kube-monitoring-overview.json

# Setup common manifest for monitoring and logging

kubectl create ns monitoring
kubectl create ns logging
kubectl create secret generic loki -n logging --from-file=loki.yaml
kubectl create -f kubelog.yaml -n logging

# Validation for Windows Node

winnode=$(kubectl get nodes -o wide | grep Windows | awk '{print $6}')

# Deploy for monitoring and logging

if [ "$winnode" == "" ]; then
 kubectl create -f linux-prometheus-configmap.yaml -n monitoring
 kubectl create -f kubemon.yaml -n monitoring
else
 wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/loki-win-ds.yaml
 wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/win-prometheus-configmap.yaml
 # Edit win-prometheus-configmap.yaml with Windows host
 sed -i "s/win-node-exporter/$winnode/g" win-prometheus-configmap.yaml
 kubectl create -f win-prometheus-configmap.yaml -n monitoring
 kubectl create -f kubemon.yaml -n monitoring
 kubectl create -f loki-win-ds.yaml -n logging
fi

## Upload Grafana dashboard & loki datasource

echo ""
echo "Waiting for Grafana POD ready to upload dashboard & loki datasource .."
while [[ $(kubectl get pods kubemon-grafana-0 -n monitoring -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

HIP=$(kubectl get svc kubemon-grafana -n monitoring | grep kubemon-grafana | awk '{print $4}')
curl -vvv http://admin:admin2675@$HIP/api/dashboards/db -X POST -d @pod-monitoring.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP/api/dashboards/db -X POST -d @kube-monitoring-overview.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP/api/datasources -X POST -d @loki-ds.json -H 'Content-Type: application/json'

kubectl get svc -n monitoring