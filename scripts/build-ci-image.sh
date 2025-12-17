#!/bin/bash
set -euo pipefail

TAG="${1:-1.0}"
REGISTRY="${REGISTRY:-${2:-39.96.223.210:5000}}"
IMAGE_REPO="${IMAGE_REPO:-${3:-dzr975336710/ci-kaniko-helm}}"

IMAGE="${REGISTRY}/${IMAGE_REPO}:${TAG}"

if [[ "${TAG}" == "-h" || "${TAG}" == "--help" ]]; then
  cat <<'EOF'
用法:
  ./build-ci-image.sh [tag] [registry] [image_repo]

默认值:
  tag:        1.0
  registry:   39.96.223.210:5000
  image_repo: dzr975336710/ci-kaniko-helm

示例:
  docker login 39.96.223.210:5000
  ./build-ci-image.sh 1.0
  ./build-ci-image.sh 1.1 39.96.223.210:5000 dzr975336710/ci-kaniko-helm
  REGISTRY=39.96.223.210:5000 ./build-ci-image.sh 1.0
EOF
  exit 0
fi

docker build -f ./docker/Dockerfile -t "${IMAGE}" .
docker push "${IMAGE}"
echo "如果 build 成功但 push 失败，可手动重试：docker push ${IMAGE}"
