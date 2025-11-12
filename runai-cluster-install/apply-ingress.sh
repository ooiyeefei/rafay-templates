#!/usr/bin/env bash
export RCTL_PROJECT=${PROJECT}
export RCTL_API_KEY=${RAFAY_API_KEY}
export RCTL_REST_ENDPOINT=${RAFAY_REST_ENDPOINT}

curl -o rctl-linux-amd64.tar.bz2 https://rafay-prod-cli.s3-us-west-2.amazonaws.com/publish/rctl-linux-amd64.tar.bz2
tar -xf rctl-linux-amd64.tar.bz2
./rctl download kubeconfig --cluster ${CLUSTER_NAME} -p ${PROJECT} > ztka-user-kubeconfig
export KUBECONFIG=ztka-user-kubeconfig
export KUBE_CONFIG_PATH=ztka-user-kubeconfig
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sleep 60
chmod +x kubectl && ./kubectl create ns runai && ./kubectl apply -f test-ingress.yaml -n runai