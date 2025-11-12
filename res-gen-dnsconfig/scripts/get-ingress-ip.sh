#!/usr/bin/env bash

rctl download kubeconfig --cluster ${CLUSTER_NAME} -p ${PROJECT} > ztka-user-kubeconfig
export KUBECONFIG=ztka-user-kubeconfig

touch ingress-ip

# check if there is customer provided the external ip
if [ -n "${CUSTOMER_INGRESS_IP}" ]; then
  echo "${CUSTOMER_INGRESS_IP}" > ingress-ip
  exit 0
fi

# check if there is ingress-nginx on the cluster
ingress_ip=$(kubectl --kubeconfig=ztka-user-kubeconfig describe svc -n ${INGRESS_NAMESPACE} |grep "LoadBalancer Ingress:"|awk '{print $3}')

if [ -n "$ingress_ip" ]; then
  echo "found ingress ip $node_ips"
  echo "$ingress_ip" > ingress-ip
  exit 0
fi

# check if there is internal ip
node_ips=$(kubectl --kubeconfig=ztka-user-kubeconfig get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{" "}{end}' | sed 's/ $//')
node_ips="${node_ips// /,}"
if [ -n "$node_ips" ]; then
  echo "found internal ips $node_ips"
  echo "$node_ips" > ingress-ip
  exit 0
fi