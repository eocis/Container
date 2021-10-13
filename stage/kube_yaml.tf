resource "local_file" "private_key" {
    content  = <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: kube-example
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: kube-example
  name: web-app
spec:
  selector:
    matchLabels:
      app: web-app
  replicas: 2
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - image: 626426825780.dkr.ecr.ap-northeast-2.amazonaws.com/kube-images:2048
        imagePullPolicy: Always
        name: web-app-container
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  namespace: kube-example
  name: web-app-np
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 80
      protocol: TCP
  selector:
    app: web-app
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: kube-example
  name: web-app-ing
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/inbound-cidrs: '0.0.0.0/0'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
    alb.ingress.kubernetes.io/subnets: "${module.vpc.private_subnets[0]},${module.vpc.private_subnets[1]}"
    alb.ingress.kubernetes.io/certificate-arn: ${data.aws_acm_certificate.cert_arn.id}
spec:
  rules:
    - host: kube.eocis.app
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: web-app-np
                port: 
                  number: 443
EOF
    filename = "./k8s/apply.yml"
    file_permission = "0644"
}