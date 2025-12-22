#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TAG="${1:-1.2}"
REGISTRY="${REGISTRY:-${2:-39.96.223.210:5000}}"
IMAGE_REPO="${IMAGE_REPO:-${3:-dzr975336710/ci-kaniko-helm}}"

IMAGE="${REGISTRY}/${IMAGE_REPO}:${TAG}"
LATEST_IMAGE="${REGISTRY}/${IMAGE_REPO}:latest"

BUILDER_NAME="${BUILDER_NAME:-ci-kaniko-helm-builder}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${ROOT_DIR}/docker/Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-1}"

GOLANG_IMAGE="${GOLANG_IMAGE:-}"
ALPINE_IMAGE="${ALPINE_IMAGE:-}"
KANIKO_VERSION="${KANIKO_VERSION:-v1.23.2}"
HELM_VERSION="${HELM_VERSION:-v3.15.4}"
HELM_BASE_URL="${HELM_BASE_URL:-}"
APK_REPO_BASE="${APK_REPO_BASE:-}"
APK_REPO_VERSION="${APK_REPO_VERSION:-}"
BUILDER_DRIVER="${BUILDER_DRIVER:-}"
MIRROR_REGISTRY="${MIRROR_REGISTRY:-2c9ttmy29gq3er.xuanyuan.run}"
BUILDKITD_CONFIG="${BUILDKITD_CONFIG:-${ROOT_DIR}/docker/buildkitd.toml}"
BUILDKIT_CONFIG="${BUILDKIT_CONFIG:-}"
BUILDER_RECREATE="${BUILDER_RECREATE:-0}"

if [[ "${TAG}" == "-h" || "${TAG}" == "--help" ]]; then
  cat <<'EOF'
用法:
  ./build-ci-image.sh [tag] [registry] [image_repo]

默认值:
  tag:        1.2
  registry:   39.96.223.210:5000
  image_repo: dzr975336710/ci-kaniko-helm

示例:
  docker login 39.96.223.210:5000
  ./build-ci-image.sh 1.2
  ./build-ci-image.sh 1.1 39.96.223.210:5000 dzr975336710/ci-kaniko-helm
  REGISTRY=39.96.223.210:5000 ./build-ci-image.sh 1.2

可选环境变量:
  BUILDER_NAME     buildx builder 名称 (默认: ci-kaniko-helm-builder)
  BUILDER_DRIVER   buildx driver (默认: PUSH=0 时为 docker，否则为 docker-container)
  BUILDKITD_CONFIG buildkitd 配置文件 (默认: docker/buildkitd.toml；用于配置 http/insecure registry)
  BUILDER_RECREATE 强制重建 builder (默认: 0；设为 1 会 docker buildx rm 并重新创建)
  DOCKERFILE_PATH  Dockerfile 路径 (默认: docker/Dockerfile)
  PLATFORM         构建平台 (默认: linux/amd64,linux/arm64)
  PUSH             是否推送镜像 (默认: 1; 设为 0 将使用 --load，且 PLATFORM 需为单一平台)
  GOLANG_IMAGE     Golang 基础镜像 (默认: 2c9ttmy29gq3er.xuanyuan.run/golang:1.22-alpine)
  ALPINE_IMAGE     Alpine 基础镜像 (默认: 2c9ttmy29gq3er.xuanyuan.run/alpine:3.20)
  KANIKO_VERSION   Kaniko 版本 (默认: v1.23.2)
  HELM_VERSION     Helm 版本 (默认: v3.15.4)
  HELM_BASE_URL    Helm 下载地址 (默认: https://get.helm.sh)
  APK_REPO_BASE    Alpine apk 镜像源 (默认: https://mirrors.aliyun.com/alpine)
  APK_REPO_VERSION Alpine 版本目录 (默认: v3.20)
  MIRROR_REGISTRY  基础镜像镜像源前缀 (默认: 2c9ttmy29gq3er.xuanyuan.run)
EOF
  exit 0
fi

output_flag="--push"
if [[ "${PUSH}" == "0" ]]; then
  if [[ "${PLATFORM}" == *","* ]]; then
    echo "ERROR: PUSH=0 时只能使用单一平台，例如 PLATFORM=linux/amd64" >&2
    exit 2
  fi
  output_flag="--load"
  if [[ -z "${BUILDER_DRIVER}" ]]; then
    BUILDER_DRIVER="docker"
  fi
elif [[ -z "${BUILDER_DRIVER}" ]]; then
  BUILDER_DRIVER="docker-container"
fi

effective_builder_name="${BUILDER_NAME}"
if docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
  existing_driver="$(docker buildx inspect "${BUILDER_NAME}" 2>/dev/null | awk -F': ' '/^Driver:/ {print $2; exit}')"
  if [[ -n "${existing_driver}" && "${existing_driver}" != "${BUILDER_DRIVER}" ]]; then
    effective_builder_name="${BUILDER_NAME}-${BUILDER_DRIVER}"
  fi
fi

if docker buildx inspect "${effective_builder_name}" >/dev/null 2>&1; then
  if [[ "${BUILDER_RECREATE}" == "1" ]]; then
    docker buildx rm -f "${effective_builder_name}" >/dev/null 2>&1 || true
  else
    docker buildx use "${effective_builder_name}"
  fi
fi

if ! docker buildx inspect "${effective_builder_name}" >/dev/null 2>&1; then
  create_args=(--use --name "${effective_builder_name}" --driver "${BUILDER_DRIVER}")
  # Back-compat: accept BUILDKIT_CONFIG but prefer BUILDKITD_CONFIG.
  if [[ -n "${BUILDKIT_CONFIG}" ]]; then
    BUILDKITD_CONFIG="${BUILDKIT_CONFIG}"
  fi
  if [[ "${BUILDER_DRIVER}" == "docker-container" && -f "${BUILDKITD_CONFIG}" ]]; then
    create_args+=(--buildkitd-config "${BUILDKITD_CONFIG}")
  fi
  docker buildx create "${create_args[@]}" >/dev/null
fi
docker buildx inspect --bootstrap >/dev/null

build_args=()
if [[ -z "${GOLANG_IMAGE}" ]]; then
  GOLANG_IMAGE="${MIRROR_REGISTRY}/golang:1.22-alpine"
fi
if [[ -z "${ALPINE_IMAGE}" ]]; then
  ALPINE_IMAGE="${MIRROR_REGISTRY}/alpine:3.20"
fi
build_args+=(--build-arg "GOLANG_IMAGE=${GOLANG_IMAGE}")
if [[ -n "${ALPINE_IMAGE}" ]]; then
  build_args+=(--build-arg "ALPINE_IMAGE=${ALPINE_IMAGE}")
fi
build_args+=(--build-arg "MIRROR_REGISTRY=${MIRROR_REGISTRY}")
build_args+=(--build-arg "KANIKO_VERSION=${KANIKO_VERSION}")
build_args+=(--build-arg "HELM_VERSION=${HELM_VERSION}")
if [[ -n "${HELM_BASE_URL}" ]]; then
  build_args+=(--build-arg "HELM_BASE_URL=${HELM_BASE_URL}")
fi
if [[ -n "${APK_REPO_BASE}" ]]; then
  build_args+=(--build-arg "APK_REPO_BASE=${APK_REPO_BASE}")
fi
if [[ -n "${APK_REPO_VERSION}" ]]; then
  build_args+=(--build-arg "APK_REPO_VERSION=${APK_REPO_VERSION}")
fi

docker buildx build --platform "${PLATFORM}" \
  -f "${DOCKERFILE_PATH}" \
  -t "${IMAGE}" \
  -t "${LATEST_IMAGE}" \
  "${build_args[@]}" \
  ${output_flag} "${ROOT_DIR}"
