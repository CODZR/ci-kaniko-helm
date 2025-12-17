#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly COMPOSE_FILENAME="docker-compose.yml"
readonly OUTPUT_DIR="${SCRIPT_DIR}"

source "${SCRIPT_DIR}/utils.sh"

# 主函数
main() {
    cd "${DEPLOY_DIR}"
    
    local rebuild_flag="false"
    local deploy_target="${DEPLOY_TARGET:-dev}"

    for arg in "$@"; do
        case "${arg}" in
            dev|prod)
                deploy_target="${arg}"
                ;;
            true|false)
                rebuild_flag="$(utils::normalize_boolean "${arg}")"
                ;;
            *)
                utils::die "Unknown argument: ${arg}"
                ;;
        esac
    done

    DEPLOY_TARGET="${deploy_target}"
    environment::resolve_profile_paths
    environment::load_deploy_env
    environment::ensure_runtime_env
    environment::require_deploy_env

    local local_compose_file="${COMPOSE_FILE}"
    if [[ ! -f "${local_compose_file}" ]]; then
        utils::die "未找到 docker-compose.yml：${local_compose_file}"
    fi

    ARCHIVE_NAME="${APP_NAME}-${APP_VERSION}.tar.gz"
    ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_NAME}"
    REMOTE_ARCHIVE="${REMOTE_HOME_DIR}/${ARCHIVE_NAME}"
    LOCAL_COMPOSE_FILE="${local_compose_file}"

    echo "================================================"
    echo "Deploy target: ${DEPLOY_TARGET}"
    echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}"
    echo "Remote dir: ${REMOTE_HOME_DIR}"
    echo "Remote compose: ${REMOTE_HOME_DIR}/${COMPOSE_FILENAME}"
    echo "Remote runtime.env: ${REMOTE_HOME_DIR}/runtime.env"
    echo "Remote archive: ${REMOTE_ARCHIVE}"
    echo "Rebuild: ${rebuild_flag}"
    echo "================================================"

    build::check_and_build "${rebuild_flag}"
    build::validate_archive
    
    local remote_user="${REMOTE_USER?Error: REMOTE_USER 未在 config.sh 中定义}"
    local remote_host_addr="${REMOTE_HOST?Error: REMOTE_HOST 未在 config.sh 中定义}"
    local remote_connection_string="${remote_user}@${remote_host_addr}"
    deploy::upload_files "${remote_connection_string}"
    deploy::run_composition "${remote_connection_string}"
    
    echo "Deployment completed successfully"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
