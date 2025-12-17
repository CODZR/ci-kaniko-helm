# 部署方法

本项目基于 **React + Vite**，构建脚本会输出 `dist` 静态资源与 Docker 镜像归档。以下流程可直接将 `deploy/` 目录打包后交付给运维或第三方。

---

## 0. 服务器修改环境变量方法
1. 进入 Compose 文件所在目录（对应 `REMOTE_HOME_DIR`）
   - 示例：`cd /home/test/combination-flooding`
2. 如果有新的镜像归档，先导入镜像，**如果只是为了修改环境变量，直接跳到第3步**
   - `.tar`：`docker load -i combination-flooding-1.0.1.tar`
   - `.tar.gz`：`gunzip -c combination-flooding-1.0.1.tar.gz | docker load`
3. **修改 `runtime.env`**
4. 重建容器以使环境变量生效
   - **`docker compose up -d --force-recreate --remove-orphans`**（或旧版 `docker-compose ...`）

如果确认之前的容器没有用了，可以删除旧容器`docker rm -f "combination-flooding" >/dev/null 2>&1 || true`


## 1. 准备运行时构建

1. 编辑环境配置（按 `DEPLOY_TARGET` 选择一套）：
   - `deploy/dev/config.sh` 与 `deploy/dev/runtime.env`
   - `deploy/prod/config.sh` 与 `deploy/prod/runtime.env`
2. 执行 `./deploy/build-docker.sh`（会在仓库根目录运行 `pnpm install && pnpm run build`，并生成 `dist/`）。
3. 该脚本会：
   - 根据 `APP_VERSION`（若未显式设置则读取 `package.json`）写入镜像名，并在 `deploy/output` 下生成 `<APP_NAME>-<version>.tar.gz`。
   - 输出镜像归档到 `deploy/output/`，部署所需脚本位于 `deploy/output/`，环境配置位于 `deploy/dev|prod/`。
4. 需要调整静态资源或服务器规则时：
   - 编辑 `deploy/Dockerfile.dev` 可以修改镜像构建方式（例如替换基础镜像、环境变量或 `serve` 运行参数）。

> 如果只需复用已有构建，可直接把 `deploy/output/<APP_NAME>-*.tar.gz`、`deploy/output/*.sh` 以及对应的 `deploy/dev|prod/` 配置目录复制到目标环境，再执行下述部署步骤。

---

## 2. 运行部署脚本（Docker Compose）

1. `deploy/dev|prod/docker-compose.yml` 为唯一需要维护的 Compose 文件，仅描述服务、镜像与端口映射；所有变量来自 `config.sh`（部署参数）与 `runtime.env`（容器运行时变量）。
2. 执行 `./deploy/output/deploy.sh [dev|prod] [true|false]`：
   - 示例：`./deploy/output/deploy.sh dev true`（构建 + 部署 dev）
   - 示例：`./deploy/output/deploy.sh prod false`（跳过构建，直接部署 prod）
3. 产物交付（最小集合）建议包含：
   - `deploy/output/deploy.sh`、`deploy/output/utils.sh`
   - `deploy/dev/` 或 `deploy/prod/`（至少一套：`config.sh`、`runtime.env`、`docker-compose.yml`）
   - 对应版本的 `deploy/output/<APP_NAME>-<version>.tar.gz`

---

## 3. 远端执行流程

部署脚本会自动完成以下动作：

1. 上传 `deploy/*/docker-compose.yml`、`runtime.env` 以及选定的 `.tar.gz` 镜像包到远端（上传目录来自 `REMOTE_HOME_DIR`）。
2. 在服务器上执行：
   - `docker load -i <APP_NAME>-<version>.tar` 将镜像导入本地。
   - `docker compose up -d --force-recreate --remove-orphans`，以 compose 文件中的环境变量启动/更新容器。
3. 脚本会多次提示输入远端密码（创建目录、上传文件、Compose 操作）。建议提前准备好凭据或配置 SSH 密钥。

---

## 4. 部署完成后的验证

1. 待脚本输出 “Deployment completed successfully” 后，即表示镜像已加载且容器已重启。
2. 在浏览器访问对应域名/端口，**强制刷新** 或清理缓存，确认最新 UI 与接口工作正常。
3. 若需要热修复配置，可直接编辑远端的 `docker-compose.yml`（默认存放在 `${REMOTE_HOME_DIR}/${COMPOSE_FILENAME}`），再执行一次 `docker compose up -d`。

---

> 📌 **快速指引**
>
> - 构建：`./deploy/build-docker.sh`
> - 部署：`./deploy/output/deploy.sh dev true`
> - 产物交付：打包整个 `deploy/` 目录（含 `dev|prod` 配置与 `output/` 镜像归档）
