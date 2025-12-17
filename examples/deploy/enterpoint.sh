#!/bin/bash
set -euo pipefail

TEMPLATE_PATH="/usr/share/nginx/html/runtime-config.js.template"
TARGET_PATH="/usr/share/nginx/html/runtime-config.js"

escape_sed_value() {
	printf '%s' "${1:-}" | sed -e 's/[\/&]/\\&/g'
}

replace_placeholder() {
	local placeholder="$1"
	local value="$2"

	local escaped
	escaped="$(escape_sed_value "${value}")"
	sed -i "s#__${placeholder}__#${escaped}#g" "${TARGET_PATH}"
}

resolve_env_value() {
	local candidate
	local value

	for candidate in "$@"; do
		if [[ -z "${candidate}" ]]; then
			continue
		fi

		value="${!candidate-}"

		if [[ -n "${value}" ]]; then
			printf '%s' "${value}"
			return
		fi
	done
}

inject_runtime_value() {
	local placeholder="$1"
	shift
	local resolved=""

	resolved="$(resolve_env_value "$@")"
	replace_placeholder "${placeholder}" "${resolved}"
}

render_runtime_config() {
	if [[ ! -f "${TEMPLATE_PATH}" ]]; then
		return
	fi

	cp "${TEMPLATE_PATH}" "${TARGET_PATH}"

	inject_runtime_value "VITE_API_BASE_URL" \
		"VITE_API_BASE_URL" 
	inject_runtime_value "VITE_USER_AUTHORIZATION_URI" \
		"VITE_USER_AUTHORIZATION_URI"
	inject_runtime_value "VITE_CLIENT_ID" \
		"VITE_CLIENT_ID" 
	inject_runtime_value "VITE_CLIENT_SECRET" \
		"VITE_CLIENT_SECRET" 
	inject_runtime_value "VITE_REDIRECT_URI" \
		"VITE_REDIRECT_URI" 
	inject_runtime_value "VITE_CHECK_TOKEN_ACCESS" \
		"VITE_CHECK_TOKEN_ACCESS" 
	inject_runtime_value "VITE_USER_INFO_URL" \
		"VITE_USER_INFO_URL" 
	inject_runtime_value "VITE_USER_ROLE_URL" \
		"VITE_USER_ROLE_URL" 
	inject_runtime_value "VITE_MAP_WFS_URL" \
		"VITE_MAP_WFS_URL" 
}

render_runtime_config

exec "$@"
