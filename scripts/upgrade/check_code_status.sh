#!/usr/bin/env bash
# this script checks module code updates and builds packages if needed
# haiqinma - 20260204 - multi-module version

set -euo pipefail
shopt -s nullglob

LOGFILE_PATH="/opt/logs"
LOGFILE_NAME="check-code-status.log"
LOGFILE="$LOGFILE_PATH/$LOGFILE_NAME"
if [[ ! -d "$LOGFILE_PATH" ]]; then
    mkdir -p "$LOGFILE_PATH"
fi

touch "$LOGFILE"

filesize=$(stat -c "%s" "$LOGFILE")
if [[ "$filesize" -ge 1048576 ]]; then
    echo -e "clear old logs at $(date) to avoid log file too big" > "$LOGFILE"
fi

script_dir=$(cd "$(dirname "$0")" || exit 1; pwd)
config_file="${script_dir}/modules.conf"
code_root="/root/code"
package_root="/opt/package"

log() {
    echo -e "$*" | tee -a "$LOGFILE"
}

usage() {
    log "Usage: $0 [module_name ...]"
}

modules=()

if [[ $# -gt 0 ]]; then
    modules=("$@")
else
    if [[ ! -f "$config_file" ]]; then
        log "ERROR! config file (${config_file}) is missing."
        usage
        exit 1
    fi
    mapfile -t modules < <(grep -Ehv '^\s*(#|$)' "$config_file")
    if [[ ${#modules[@]} -eq 0 ]]; then
        log "ERROR! module list is empty in ${config_file}."
        exit 1
    fi
fi

mkdir -p "$package_root"

index=1
log "\nstep $index -- begin check code status [$(date)]"

for module_name in "${modules[@]}"; do
    index=$((index+1))
    log "\nstep $index -- check module [${module_name}]"

    module_dir="${code_root}/${module_name}"
    if [[ ! -d "$module_dir" ]]; then
        log "ERROR! code directory is missing: ${module_dir}"
        exit 2
    fi

    if [[ ! -d "${module_dir}/.git" ]]; then
        log "ERROR! not a git repository: ${module_dir}"
        exit 2
    fi

    old_rev=$(git -C "$module_dir" rev-parse HEAD)
    if ! git -C "$module_dir" pull >> "$LOGFILE" 2>&1; then
        log "ERROR! git pull failed for ${module_name}"
        exit 3
    fi
    new_rev=$(git -C "$module_dir" rev-parse HEAD)

    if [[ "$old_rev" == "$new_rev" ]]; then
        log "no update for ${module_name}"
        continue
    fi

    package_script="${module_dir}/scripts/package.sh"
    if [[ ! -f "$package_script" ]]; then
        log "ERROR! package script is missing: ${package_script}"
        exit 4
    fi

    log "code updated, build package for ${module_name}"
    if ! (cd "$module_dir" && bash scripts/package.sh >> "$LOGFILE" 2>&1); then
        log "ERROR! package script failed for ${module_name}"
        exit 5
    fi

    package_candidates=("${module_dir}/output/${module_name}-"*.tar.gz)
    if [[ ${#package_candidates[@]} -eq 0 ]]; then
        log "ERROR! package file not found: ${module_dir}/output/${module_name}-*.tar.gz"
        exit 6
    fi
    package_file=$(ls -t "${package_candidates[@]}" | head -n 1)

    old_packages=("${package_root}/${module_name}-"*.tar.gz)
    if [[ ${#old_packages[@]} -gt 0 ]]; then
        rm -f "${old_packages[@]}"
    fi
    cp -f "$package_file" "$package_root/"
    log "package copied to ${package_root}/$(basename "$package_file")"
done

index=$((index+1))
log "\nstep $index -- all done. [$(date)]"
