# ci-kaniko-helm

用于构建一个 CI 镜像，镜像内包含：
- `kaniko`
- `helm`
- `chart_build.sh`（用于 Helm Chart 的依赖更新、lint、打包）

## 目录与文件说明

- `docker/Dockerfile`：构建 CI 镜像（Kaniko + Helm + 打包脚本）。
- `scripts/chart_build.sh`：遍历 `charts/*`，执行 `helm dependency update`、`helm lint`、`helm package`，输出到 `chart-packages/`。
- `scripts/build-ci-image.sh`：构建并推送 CI 镜像到指定 Registry（主逻辑）。
- `build-ci-image.sh`：便捷入口脚本（转调 `scripts/build-ci-image.sh`）。
- `tmp/`：临时工作目录（本仓库内部使用，不影响核心逻辑；不需要可清理）。
- `examples/`：示例与用法（如何构建/推送、如何在 CI 中引用镜像）。

## 构建并推送镜像

说明：Dockerfile 默认使用 `2c9ttmy29gq3er.xuanyuan.run` 作为镜像源来拉取基础镜像（`golang`/`alpine`），并在构建时：

- 从 `deps/kaniko-*.tar.gz` 编译生成 `kaniko`（避免依赖 gcr.io 镜像）
- 从 `https://get.helm.sh` 下载 Helm（可用 `HELM_VERSION`/`HELM_BASE_URL` 覆盖）
- 通过 Alpine apk 镜像源安装少量依赖（bash/curl/tar 等），默认使用阿里云镜像（可用 `APK_REPO_BASE`/`APK_REPO_VERSION` 覆盖）

### 从头开始（推荐流程）

1) 确认 Docker Buildx 可用：

```bash
docker buildx version
```

2) 登录你要推送的 Registry（默认脚本会 `--push`，所以需要先登录）：

```bash
docker login 39.96.223.210:5000
```

如果遇到 `http: server gave HTTP response to HTTPS client`，这是 buildx 的 BuildKit 容器默认按 HTTPS 访问 registry 导致的。脚本默认使用 `docker/buildkitd.toml`（`BUILDKITD_CONFIG`）给 BuildKit 配置该 registry 为 `http/insecure`；仅当你之前创建过未带该配置的 builder 时，才需要重建一次：

```bash
BUILDER_RECREATE=1 ./build-ci-image.sh 1.2
```

3) 构建并推送（默认双架构 `linux/amd64,linux/arm64`，示例 tag：`1.2`）：

```bash
./build-ci-image.sh 1.2
```

推送后可验证（该 Registry 是 http/insecure 时需要加 `--insecure`）：

```bash
docker manifest inspect --insecure 39.96.223.210:5000/dzr975336710/ci-kaniko-helm:1.2
docker manifest inspect --insecure 39.96.223.210:5000/dzr975336710/ci-kaniko-helm:latest
```

### 常用变体

本地构建（不推送，单一架构；用于验证 Dockerfile 能跑通）：

```bash
PUSH=0 PLATFORM=linux/amd64 ./build-ci-image.sh 1.2
```

自定义 registry / 镜像仓库名（示例）：

```bash
./build-ci-image.sh 1.2 39.96.223.210:5000 dzr975336710/ci-kaniko-helm
```

自定义镜像源（基础镜像）：

```bash
MIRROR_REGISTRY=2c9ttmy29gq3er.xuanyuan.run \
./build-ci-image.sh 1.2
```

或单独覆盖基础镜像：

```bash
GOLANG_IMAGE=your-registry.example.com/library/golang:1.22-alpine \
ALPINE_IMAGE=39.96.223.210:5000/library/alpine:3.20 \
./build-ci-image.sh 1.2
```

自定义 Helm 下载源/版本示例：

```bash
HELM_VERSION=v3.15.4 \
HELM_BASE_URL=https://get.helm.sh \
./build-ci-image.sh 1.2
```

## 在 CI 中引用

参考 `examples/README.md` 与 `examples/gitlab-ci.yml`。
