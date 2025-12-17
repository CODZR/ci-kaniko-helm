# ci-kaniko-helm

用于构建一个 CI 镜像，镜像内包含：
- `kaniko`（从 `deps/` 中的源码/依赖离线构建）
- `helm`
- `chart_build.sh`（用于 Helm Chart 的依赖更新、lint、打包）

## 目录与文件说明

- `docker/Dockerfile`：构建 CI 镜像（Kaniko + Helm + 打包脚本）。
- `scripts/chart_build.sh`：遍历 `charts/*`，执行 `helm dependency update`、`helm lint`、`helm package`，输出到 `chart-packages/`。
- `scripts/build-ci-image.sh`：构建并推送 CI 镜像到指定 Registry（主逻辑）。
- `build-ci-image.sh`：便捷入口脚本（转调 `scripts/build-ci-image.sh`）。
- `deps/`：离线依赖与缓存（Kaniko 源码包、Helm 安装包、apk 缓存等）。
- `tmp/`：临时工作目录（本仓库内部使用，不影响核心逻辑；不需要可清理）。
- `examples/`：示例与用法（如何构建/推送、如何在 CI 中引用镜像）。

## 构建并推送镜像

先登录 Registry：

```bash
docker login 39.96.223.210:5000
```

构建并推送（示例 tag：`1.0`）：

```bash
./build-ci-image.sh 1.0
```

自定义 registry / 镜像仓库名：

```bash
./build-ci-image.sh 1.0 39.96.223.210:5000 dzr975336710/ci-kaniko-helm
```

## 在 CI 中引用

参考 `examples/README.md` 与 `examples/gitlab-ci.yml`。
