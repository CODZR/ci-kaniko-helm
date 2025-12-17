#!/usr/bin/env bash
set -euo pipefail

readonly UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UTILS_DEPLOY_DIR="$(cd "${UTILS_DIR}/.." && pwd)"
readonly PROJECT_ROOT="$(cd "${UTILS_DEPLOY_DIR}/.." && pwd)"
readonly DEFAULT_TARGET_PLATFORM="linux/amd64"

CONFIG_FILE=""
RUNTIME_ENV_FILE=""
COMPOSE_FILE=""

# 共享部署工具函数，供 build 与 deploy 脚本复用。

utils::normalize_boolean() {
    printf '%s' "${1:-false}" | tr '[:upper:]' '[:lower:]'
}


utils::die() {
    echo "Error: $1" >&2
    exit 1
}

utils::check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        utils::die "'$1' is required but not installed."
    fi
}

utils::get_version() {
    if [[ -n "${APP_VERSION:-}" ]]; then
        printf '%s' "${APP_VERSION}"
        return 0
    fi

    local package_file="${PROJECT_ROOT}/package.json"

    if [[ -f "${package_file}" ]]; then
        node --eval="process.stdout.write(require('${package_file}').version)" 2>/dev/null && return 0
    fi

    utils::die "无法解析版本号，请确认 docker-compose.yml 或 package.json 中的版本设置"
}

utils::detect_platform() {
    local machine
    machine="$(uname -m)"

    case "${machine}" in
        x86_64|amd64) echo "linux/amd64" ;;
        arm64|aarch64) echo "linux/arm64/v8" ;;
        *) echo "linux/amd64" ;;
    esac
}

utils::setup_temp_dir() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "${temp_dir}"' EXIT
    echo "${temp_dir}"
}

utils::require_var() {
    local key="$1"
    local value="${!key-}"

    if [[ -z "${value}" ]]; then
        utils::die "未设置 ${key}，请在 ${CONFIG_FILE} 中定义"
    fi
}


environment::load_deploy_env() {
    if [[ -z "${CONFIG_FILE}" ]]; then
        environment::resolve_profile_paths
    fi

    set -a
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    set +a

    return 0
}

environment::require_build_env() {
    utils::require_var "APP_NAME"
}

environment::require_deploy_env() {
    utils::require_var "APP_NAME"
    utils::require_var "APP_VERSION"
    utils::require_var "REMOTE_USER"
    utils::require_var "REMOTE_HOST"
    utils::require_var "REMOTE_HOME_DIR"
    utils::require_var "EXPOSED_PORT"
    utils::require_var "CONTAINER_PORT"
}

environment::ensure_runtime_env() {
    if [[ -z "${RUNTIME_ENV_FILE}" ]]; then
        environment::resolve_profile_paths
    fi

    if [[ ! -f "${RUNTIME_ENV_FILE}" ]]; then
        utils::die "未找到 ${RUNTIME_ENV_FILE}，请根据 Kubernetes 使用的环境变量创建该文件"
    fi
}

environment::resolve_profile_paths() {
    DEPLOY_TARGET="${DEPLOY_TARGET:-dev}"
    case "${DEPLOY_TARGET}" in
        dev|prod) ;;
        *)
            utils::die "DEPLOY_TARGET 仅支持 dev/prod，当前值：${DEPLOY_TARGET}"
            ;;
    esac

    local profile_dir=""
    local candidate_dir=""

    # 优先使用同目录（output 包）下的配置，其次使用仓库内的 deploy/{dev|prod} 配置。
    candidate_dir="${UTILS_DIR}/${DEPLOY_TARGET}"
    if [[ -f "${candidate_dir}/config.sh" ]]; then
        profile_dir="${candidate_dir}"
    elif [[ -f "${UTILS_DIR}/config.sh" ]]; then
        profile_dir="${UTILS_DIR}"
    else
        profile_dir="${UTILS_DEPLOY_DIR}/${DEPLOY_TARGET}"
    fi

    CONFIG_FILE="${profile_dir}/config.sh"
    RUNTIME_ENV_FILE="${profile_dir}/runtime.env"
    COMPOSE_FILE="${profile_dir}/docker-compose.yml"

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        utils::die "未找到 config.sh：${CONFIG_FILE}"
    fi
    if [[ ! -f "${RUNTIME_ENV_FILE}" ]]; then
        utils::die "未找到 runtime.env：${RUNTIME_ENV_FILE}"
    fi
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        utils::die "未找到 docker-compose.yml：${COMPOSE_FILE}"
    fi
}

environment::format_env_assignment() {
    local key="$1"
    local value="$2"
    printf '%s=%s' "${key}" "$(printf '%q' "${value}")"
}

build::check_and_build() {
    local rebuild_flag="$1"

    if [[ "${rebuild_flag}" == "true" ]]; then
        TARGET_PLATFORM="${TARGET_PLATFORM:-${DEFAULT_TARGET_PLATFORM}}" "${UTILS_DEPLOY_DIR}/build-docker.sh"
    fi
}

build::validate_archive() {
    if [[ ! -f "${ARCHIVE_PATH}" ]]; then
        echo "Archive '${ARCHIVE_PATH}' not found." >&2
        return 1
    fi
}

deploy::upload_files() {
    local remote_host="$1"

    echo ">>> Uploading files to ${remote_host}:${REMOTE_HOME_DIR}"
    ssh "${remote_host}" "mkdir -p \"${REMOTE_HOME_DIR}\""
    scp "${LOCAL_COMPOSE_FILE}" "${remote_host}:${REMOTE_HOME_DIR}/${COMPOSE_FILENAME}"
    scp "${RUNTIME_ENV_FILE}" "${remote_host}:${REMOTE_HOME_DIR}/runtime.env"
    scp "${ARCHIVE_PATH}" "${remote_host}:${REMOTE_ARCHIVE}"
    echo ">>> Uploaded:"
    echo " - docker-compose.yml -> ${REMOTE_HOME_DIR}/${COMPOSE_FILENAME}"
    echo " - runtime.env -> ${REMOTE_HOME_DIR}/runtime.env"
    echo " - archive -> ${REMOTE_ARCHIVE}"
}

deploy::run_compose_remote() {
    local remote_host="$1"
    local remote_env=""
    remote_env+="$(environment::format_env_assignment "APP_NAME" "${APP_NAME}") "
    remote_env+="$(environment::format_env_assignment "APP_VERSION" "${APP_VERSION}") "
    remote_env+="$(environment::format_env_assignment "REMOTE_HOME_DIR" "${REMOTE_HOME_DIR}") "
    remote_env+="$(environment::format_env_assignment "REMOTE_ARCHIVE" "${REMOTE_ARCHIVE}") "
    remote_env+="$(environment::format_env_assignment "EXPOSED_PORT" "${EXPOSED_PORT}") "
    remote_env+="$(environment::format_env_assignment "CONTAINER_PORT" "${CONTAINER_PORT}") "

    ssh "${remote_host}" "${remote_env}bash -s" <<'HEREDOC_COMPOSE'
set -euo pipefail

archive="${REMOTE_ARCHIVE}"

if [[ -f "${archive}" ]]; then
  if [[ "${archive}" == *.gz ]]; then
    gunzip -f "${archive}"
    archive="${archive%.gz}"
  fi

  docker load -i "${archive}"
fi

if docker ps -aq --filter "name=^${APP_NAME}$" | grep -q .; then
  docker rm -f "${APP_NAME}" >/dev/null 2>&1 || true
fi

export COMPOSE_PROJECT_NAME="${APP_NAME}"
cd "${REMOTE_HOME_DIR}"

compose_cmd="docker compose"
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    compose_cmd="docker-compose"
  else
    echo "Error: 目标机器缺少 docker compose / docker-compose" >&2
    exit 1
  fi
fi

${compose_cmd} up -d --force-recreate --remove-orphans
HEREDOC_COMPOSE
}

deploy::run_composition() {
    local remote_host="$1"
    deploy::run_compose_remote "${remote_host}"
}
