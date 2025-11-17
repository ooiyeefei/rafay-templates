apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: runai-cluster-ingress
  namespace: ${namespace}
  annotations:
    # Tell cert-manager to issue a certificate for this Ingress
    cert-manager.io/cluster-issuer: "${cluster_issuer_name}"

    # NGINX-specific annotations
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

    # Increase timeouts for long-running operations
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"

    # WebSocket support (if needed by Run:AI)
    nginx.ingress.kubernetes.io/websocket-services: "runai-cluster-ingress"
spec:
  ingressClassName: nginx

  tls:
  - hosts:
    - ${cluster_fqdn}
    # cert-manager will create this secret automatically
    secretName: ${tls_secret_name}

  rules:
  - host: ${cluster_fqdn}
    http:
      paths:
      # Route all traffic to Run:AI cluster ingress service
      - path: /
        pathType: Prefix
        backend:
          service:
            # This service is created by the Run:AI Helm chart
            name: runai-cluster-ingress
            port:
              number: 443
