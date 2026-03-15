#!/usr/bin/env bash
# upgrade warehouse service from one deployed version to another

set -euo pipefail
shopt -s nullglob

script_dir=$(cd "$(dirname "$0")" || exit 1; pwd)
# shellcheck disable=SC1091
source "${script_dir}/common.sh"

init_log_file "upgrade-warehouse.log"

module_name="warehouse"
deploy_root="/opt/deploy"

usage() {
    log "Usage: $0 [current_version] [target_version]"
}

resolve_version_dir() {
    local version=$1
    local candidates=()
    local dir

    for dir in "${deploy_root}/${module_name}-v${version}-"*; do
        if [[ -d "$dir" ]]; then
            candidates+=("$(basename "$dir")")
        fi
    done

    if [[ ${#candidates[@]} -eq 0 ]]; then
        return 1
    fi

    select_latest_named_item "$module_name" "${candidates[@]}" || return 1
    printf '%s/%s' "$deploy_root" "$SELECTED_NAME"
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

current_version=$(trim "$1")
target_version=$(trim "$2")

if [[ -z "$current_version" || -z "$target_version" ]]; then
    usage
    exit 1
fi

current_dir=$(resolve_version_dir "$current_version") || {
    log "ERROR! current version directory is missing: /opt/deploy/warehouse-v${current_version}-****"
    exit 1
}
target_dir=$(resolve_version_dir "$target_version") || {
    log "ERROR! target version directory is missing: /opt/deploy/warehouse-v${target_version}-****"
    exit 1
}

log "current dir: ${current_dir}"
log "target dir: ${target_dir}"

[[ -f "${current_dir}/scripts/starter.sh" ]] || { log "ERROR! missing script: ${current_dir}/scripts/starter.sh"; exit 1; }
[[ -f "${target_dir}/scripts/starter.sh" ]] || { log "ERROR! missing script: ${target_dir}/scripts/starter.sh"; exit 1; }
[[ -f "${current_dir}/config.yaml" ]] || { log "ERROR! missing config: ${current_dir}/config.yaml"; exit 1; }

log "stop current warehouse: cd ${current_dir} && scripts/starter.sh stop"
if ! (cd "$current_dir" && bash scripts/starter.sh stop >> "$LOGFILE" 2>&1); then
    log "ERROR! failed to stop current warehouse service"
    exit 1
fi

cp -f "${current_dir}/config.yaml" "${target_dir}/config.yaml"
log "copied config: ${current_dir}/config.yaml -> ${target_dir}/config.yaml"

log "start target warehouse: cd ${target_dir} && scripts/starter.sh"
if ! (cd "$target_dir" && bash scripts/starter.sh >> "$LOGFILE" 2>&1); then
    log "ERROR! failed to start target warehouse service"
    exit 1
fi

log "warehouse upgrade done: ${current_version} -> ${target_version}"
