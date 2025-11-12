#!/usr/bin/env bash
export RCTL_PROJECT=${PROJECT}
export RCTL_API_KEY=${RAFAY_API_KEY}
export RCTL_REST_ENDPOINT=${RAFAY_REST_ENDPOINT}

curl -o rctl-linux-amd64.tar.bz2 https://rafay-prod-cli.s3-us-west-2.amazonaws.com/publish/rctl-linux-amd64.tar.bz2
tar -xf rctl-linux-amd64.tar.bz2
./rctl download kubeconfig --cluster ${CLUSTER_NAME} -p ${PROJECT} > ztka-user-kubeconfig
export KUBECONFIG=ztka-user-kubeconfig
export KUBE_CONFIG_PATH=ztka-user-kubeconfig
#sleep 300
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && ./kubectl describe svc -n ingress-nginx |grep "LoadBalancer Ingress:"|awk '{print $3}' > ingress-ip