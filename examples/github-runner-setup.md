# GitHub Actions（自建 Runner）部署到本机 k3s

由于 `39.96.223.210:5000` 是 HTTP/私有 Registry，且 GitHub Hosted Runner 不能方便地配置 Docker daemon 的 insecure registry，
建议在 `39.96.223.210` 上安装 **self-hosted runner** 来执行构建与部署。

## 1) 服务器侧准备

### 1.1 创建 runner 用户并赋权（示例）

```bash
sudo useradd -m -s /bin/bash github-runner || true
sudo usermod -aG docker github-runner
```

### 1.2 让 runner 用户能访问 k3s kubeconfig

```bash
sudo -u github-runner mkdir -p /home/github-runner/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/github-runner/.kube/config
sudo chown -R github-runner:github-runner /home/github-runner/.kube

# 确认 runner 用户能执行
sudo -u github-runner kubectl get nodes
```

### 1.3 安装 Helm（若服务器未安装）

```bash
curl -fsSL https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz -o /tmp/helm.tgz
tar -zxf /tmp/helm.tgz -C /tmp
sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm
helm version
```

## 2) GitHub 仓库侧配置

在 GitHub 仓库 `Settings → Secrets and variables → Actions` 添加：

- `REGISTRY_USER`：`dzr975336710`
- `REGISTRY_PASS`：你的 registry 密码
（可选）Variables：
- `REGISTRY_HOST`：registry 地址（默认 `39.96.223.210:5000`）
- `K8S_NAMESPACE`：命名空间（默认 `test-app`）

Workflow：`.github/workflows/k3s-test.yml`

## 3) 访问

Helm Chart 默认 `NodePort=30080`，部署成功后访问：

`http://39.96.223.210:30080/`
