#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 配置常量
# ==============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEPLOY_DIR="${SCRIPT_DIR}"
readonly DEPLOY_OUTPUT_DIR="${DEPLOY_DIR}/output"
readonly ROOT_DIST_DIR="${ROOT_DIR}/dist"

source "${DEPLOY_OUTPUT_DIR}/utils.sh"

environment::load_deploy_env
environment::ensure_runtime_env
environment::require_build_env


# 检查构建依赖
build::check_dependencies() {
    local deps=("docker" "gzip" "tar")
    local skip_flag
    skip_flag="$(utils::normalize_boolean "${SKIP_APP_PREP:-false}")"

    if [[ "${skip_flag}" != "true" ]]; then
        deps+=("pnpm" "node")
    fi

    for dep in "${deps[@]}"; do
        utils::check_command "${dep}"
    done

    if ! docker buildx version >/dev/null 2>&1; then
        utils::die "docker buildx is required"
    fi
}

# 生成 dist 静态资源
build::prepare_app_bundle() {
    local skip_flag
    skip_flag="$(utils::normalize_boolean "${SKIP_APP_PREP:-false}")"

    if [[ "${skip_flag}" == "true" ]]; then
        echo "SKIP_APP_PREP=true，沿用现有 dist 目录"
    else
        (
            cd "${ROOT_DIR}"
            pnpm run build
        )
    fi

    if [[ ! -d "${ROOT_DIST_DIR}" ]]; then
        utils::die "未找到 dist 目录，请确认 pnpm run build 是否成功"
    fi
}

# 准备构建上下文
build::prepare_context() {
    local context_dir="$1"

    # 复制必要文件
    mkdir -p "${context_dir}"
    cp "${DEPLOY_DIR}/Dockerfile.dev" "${context_dir}/"
    cp "${DEPLOY_DIR}/default.conf" "${context_dir}/"
    cp "${DEPLOY_DIR}/enterpoint.sh" "${context_dir}/"

    rm -rf "${context_dir}/dist"
    mkdir -p "${context_dir}/dist"
    cp -R "${ROOT_DIST_DIR}/." "${context_dir}/dist/"

    echo "${context_dir}"
}

# 构建 Docker 镜像
build::create_docker_image() {
    local context_dir="$1"
    local tag="$2"
    local target_platform="$3"
    local output_file="$4"
    
    echo "Building Docker image ${tag} for ${target_platform}..."
    
    docker buildx build \
        --file "${context_dir}/Dockerfile.dev" \
        --platform "${target_platform}" \
        --tag "${tag}" \
        --output "type=docker,dest=${output_file}" \
        --progress plain \
        "${context_dir}"
    
    echo "✓ Docker image built successfully"
}

# 压缩镜像文件
build::compress_archive() {
    local source_tar="$1"
    local dest_gz="${source_tar}.gz"

    echo "Compressing ${source_tar}..."
    gzip -f "${source_tar}"

    if [[ ! -f "${dest_gz}" ]]; then
        utils::die "Failed to compress archive ${dest_gz}"
    fi

    echo "Archive compressed: ${dest_gz}"
}


# ==============================================================================
# 主函数
# ==============================================================================


main() {
    local version tag target_platform temp_dir context_dir
    local archive_name archive_tar archive_gz
    
    cd "${ROOT_DIR}"
    
    # 初始化变量
    version="$(utils::get_version)"
    tag="${APP_NAME}:${version}"
    target_platform="${TARGET_PLATFORM:-$(utils::detect_platform)}"
    
    # 设置文件路径
    archive_name="${APP_NAME}-${version}.tar"
    archive_tar="${DEPLOY_OUTPUT_DIR}/${archive_name}"
    archive_gz="${archive_tar}.gz"
    
    # 创建部署目录
    mkdir -p "${DEPLOY_OUTPUT_DIR}"
    
    # 清理旧文件
    rm -f "${archive_tar}" "${archive_gz}"
    
    echo "================================================"
    echo "Building ${APP_NAME} v${version}"
    echo "Platform: ${target_platform}"
    echo "Output: ${archive_gz}"
    echo "================================================"

    # 执行构建流程
    build::check_dependencies
    build::prepare_app_bundle

    temp_dir="$(utils::setup_temp_dir)"
    context_dir="${temp_dir}/context"
    mkdir -p "${context_dir}"
    
    build::prepare_context "${context_dir}"
    build::create_docker_image "${context_dir}" "${tag}" "${target_platform}" "${temp_dir}/${archive_name}"
    
    # 移动并压缩文件
    mv "${temp_dir}/${archive_name}" "${archive_tar}"
    build::compress_archive "${archive_tar}" "${archive_gz}"
    
    # 输出构建信息
    echo ""
    echo "================================================"
    echo "Build completed successfully!"
    echo "Image tag: ${tag}"
    echo "Archive: ${archive_gz}"
    echo "Size: $(du -h "${archive_gz}" | cut -f1)"
    echo "================================================"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
