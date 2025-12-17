# 示例（examples）

## 1) 构建并推送 CI 镜像

```bash
docker login 39.96.223.210:5000
./build-ci-image.sh 1.0
```

指定 registry / 镜像仓库名：

```bash
./build-ci-image.sh 1.0 39.96.223.210:5000 dzr975336710/ci-kaniko-helm
```

## 2) 在 CI 中作为 Runner 镜像使用（GitLab 示例）

参考 `examples/gitlab-ci.yml`。

## 3) 关于自签 HTTPS 证书（Colima）

如果你的 Registry 使用自签 HTTPS（例如访问 `https://39.96.223.210/v2/` 返回的证书 CN 还是 `registry.dzrlab.space`），
那么在 Colima 里需要把对应 host/IP 加到 `insecure-registries`，否则 `docker login/push` 会因为证书校验失败。

Colima 配置文件：`~/.colima/default/colima.yaml`

```yaml
docker:
  insecure-registries:
    - "39.96.223.210"
