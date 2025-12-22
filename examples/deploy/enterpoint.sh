#!/bin/sh
set -eu

TEMPLATE_PATH="/usr/share/nginx/html/runtime-config.js.template"
TARGET_PATH="/usr/share/nginx/html/runtime-config.js"

escape_sed_value() {
	printf '%s' "${1-}" | sed -e 's/[\/&]/\\&/g'
}

replace_placeholder() {
	placeholder="$1"
	value="$2"

	escaped="$(escape_sed_value "${value}")"
	sed -i "s#__${placeholder}__#${escaped}#g" "${TARGET_PATH}"
}

resolve_env_value() {
	for candidate in "$@"; do
		[ -n "${candidate}" ] || continue

		# candidate 为固定的环境变量名列表，不来自外部输入
		eval "value=\${${candidate}-}"
		if [ -n "${value-}" ]; then
			printf '%s' "${value}"
			return 0
		fi
	done

	return 0
}

inject_runtime_value() {
	placeholder="$1"
	shift

	resolved="$(resolve_env_value "$@")"
	replace_placeholder "${placeholder}" "${resolved}"
}

render_runtime_config() {
	[ -f "${TEMPLATE_PATH}" ] || return 0

	cp "${TEMPLATE_PATH}" "${TARGET_PATH}"

	inject_runtime_value "NEXT_PUBLIC_API_BASE_URL" \
		"NEXT_PUBLIC_API_BASE_URL" 
	inject_runtime_value "NEXT_PUBLIC_USER_AUTHORIZATION_URI" \
		"NEXT_PUBLIC_USER_AUTHORIZATION_URI"
	inject_runtime_value "NEXT_PUBLIC_CLIENT_ID" \
		"NEXT_PUBLIC_CLIENT_ID" 
	inject_runtime_value "NEXT_PUBLIC_CLIENT_SECRET" \
		"NEXT_PUBLIC_CLIENT_SECRET" 
	inject_runtime_value "NEXT_PUBLIC_REDIRECT_URI" \
		"NEXT_PUBLIC_REDIRECT_URI" 
	inject_runtime_value "NEXT_PUBLIC_CHECK_TOKEN_ACCESS" \
		"NEXT_PUBLIC_CHECK_TOKEN_ACCESS" 
	inject_runtime_value "NEXT_PUBLIC_USER_INFO_URL" \
		"NEXT_PUBLIC_USER_INFO_URL" 
	inject_runtime_value "NEXT_PUBLIC_USER_ROLE_URL" \
		"NEXT_PUBLIC_USER_ROLE_URL" 
	inject_runtime_value "NEXT_PUBLIC_MAP_WFS_URL" \
		"NEXT_PUBLIC_MAP_WFS_URL" 
}

render_runtime_config

exec "$@"
