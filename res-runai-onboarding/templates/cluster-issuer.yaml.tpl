apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${cluster_issuer_name}
spec:
  acme:
    # Email for Let's Encrypt notifications
    email: ${letsencrypt_email}

    # Let's Encrypt production server
    server: https://acme-v02.api.letsencrypt.org/directory

    # Secret to store the account private key
    privateKeySecretRef:
      name: ${cluster_issuer_name}-account-key

    # Use HTTP-01 challenge with NGINX Ingress
    solvers:
    - http01:
        ingress:
          class: nginx
