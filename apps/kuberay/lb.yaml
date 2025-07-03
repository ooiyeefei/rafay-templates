apiVersion: v1
kind: Service
metadata:
  name: kuberay-dashboard-service
  namespace: ${namespace}
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
spec:
  # This selector targets the KubeRay head pod created by the Helm chart.
  selector:
    ray.io/cluster: ray-cluster-kuberay
    ray.io/node-type: head
  type: LoadBalancer
  ports:
  - name: dashboard
    protocol: TCP
    port: 80
    targetPort: 8265