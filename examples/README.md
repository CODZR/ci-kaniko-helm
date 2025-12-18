# 示例（examples）

## 1) build/push CI 基础镜像（ci-kaniko-helm）

```bash
docker login 39.96.223.210:5000
./build-ci-image.sh 1.0
```

## 2) 示例应用：k3s-test（Nginx 静态站）

示例目录结构：

- `examples/dist/`：静态资源（Nginx 直接托管）
- `examples/deploy/Dockerfile`：把 `examples/dist/` 打进镜像
- `examples/charts/k3s-test/`：Helm chart（Deployment/Service/Ingress 可选）
- `examples/charts/k3s-test/`：Helm chart（Deployment/Service/NodePort，Ingress 可选）
- `examples/gitlab-ci.yml`：示例 CI（build 镜像 + helm 部署）

## 3) Registry 启用账号密码后的设置（k3s/Helm）

当 `39.96.223.210:5000` 启用了 Basic Auth 后，k3s 拉镜像需要 `imagePullSecret`。

示例（namespace 以 `test-app` 为例）：

```bash
kubectl create ns test-app || true
kubectl -n test-app create secret docker-registry regcred \
  --docker-server=39.96.223.210:5000 \
  --docker-username=dzr975336710 \
  --docker-password='你的密码'
```

Helm values 里配置 `imagePullSecrets`（见 `examples/charts/k3s-test/values.yaml`）：

```yaml
imagePullSecrets:
  - name: regcred
```

## 4) GitLab CI 变量（建议放在项目 Settings → CI/CD → Variables）

`examples/gitlab-ci.yml` 需要这些变量：

- `KUBE_CONFIG_B64`：k3s kubeconfig 的 base64（内容型变量）
- `REGISTRY_USER`：registry 用户名（例：`dzr975336710`）
- `REGISTRY_PASS`：registry 密码

## 5) 访问方式（NodePort）

该示例 Chart 默认使用 `NodePort`，端口在 `examples/charts/k3s-test/values.yaml` 的 `service.nodePort`（默认 `30080`）。
部署成功后可用 `http://39.96.223.210:30080/` 访问（前提：服务器防火墙/安全组放行该端口）。
