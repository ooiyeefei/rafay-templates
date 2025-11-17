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
    nginx.ingress.kubernetes.io/websocket-services: "researcher-service"
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
      # Route all traffic to Run:AI researcher service (main UI/API)
      - path: /
        pathType: Prefix
        backend:
          service:
            # researcher-service is the main user-facing service created by Run:AI Helm chart
            name: researcher-service
            port:
              number: 4180
