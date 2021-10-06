> ## AWS Infra 구조

> ## EKS Cluster 구조

> ## About Code

### [/stage/main.tf]


### [/stage/k8s/sample_kube.yml]

- NameSpace: kube-example
    - Default NameSpace가 아닌 별도의 NameSpace를 만들어 실습 환경을 구축하였습니다.
    - metadata.name: kube-example

- Deployment: web-app
    - <b>2048 웹게임 이미지를 사용하였습니다.</b>
    - spec.template.metadata.labels.app: web-app
    - spec.template.spec.containers.image: 26426825780.dkr.ecr.ap-northeast-2.amazonaws.com/kube-images:2048
    - spec.template.spec.containers.ports.containerPort: 80

- Service(NodePort): web-app-np
    - <b>CluterIP 대신 NodePort를 만들어 연결했습니다.</b>
    - spec.ports.port: 443
    - spec.ports.targetPort: 80
    - spec.ports.protocol: TCP
    - metadata.name: web-app.np
    - spec.selector.app: web-app

- Ingress: web-app-ing
    - <b>AWS EKS자원을 LoadBalancer를 통해 부하 분산시키기 위해서는 Ingress-Controller를 두어야 합니다.</b>
    이는 Docs에 있는 샘플 파일을 참고하여 Ingress코드를 작성하였습니다.
    - metadata.name: web-app-ing
    - spec.rules.host: kube.eocis.app
    - spec.rules.http.paths.backend.service.name: web-app-np
    - spec.rules.http.paths.backend.service.port.number: 443

> ## How to Use?

Edit: /stage/k8s/apply.yml (line 59 : host)

```sh
> terraform apply --auto-approve

> aws eks --region <region> update-kubeconfig --name <cluster_name>

> helm repo add eks https://aws.github.io/eks-charts

> helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=<cluster_name>

> kubectl apply -f ./stage/k8s/apply.yml

> kubectl describe ingress -n kube-example | grep Address   # 해당 주소를 DNS CNAME에 등록
```

참고: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/deploy/installation/