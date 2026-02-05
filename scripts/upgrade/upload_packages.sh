#!/usr/bin/env bash
# upload module packages in /opt/package to WebDAV
# haiqinma - 20260204 - first version

set -euo pipefail
shopt -s nullglob

LOGFILE_PATH="/opt/logs"
LOGFILE_NAME="upload-packages.log"
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
env_file="${script_dir}/.env"
package_root="/opt/package"
base_url="${WEBDAV_BASE_URL:-https://webdav.yeying.pub}"
prefix="${WEBDAV_PREFIX:-}"

log() {
    echo -e "$*" | tee -a "$LOGFILE"
}

usage() {
    log "Usage: $0 [module_name ...]"
}

if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "$env_file"
    set +a
fi

auth_args=()
if [[ -n "${WEBDAV_TOKEN:-}" ]]; then
    auth_args=(-H "Authorization: Bearer ${WEBDAV_TOKEN}")
elif [[ -n "${WEBDAV_USERNAME:-}" && -n "${WEBDAV_PASSWORD:-}" ]]; then
    auth_args=(-u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}")
else
    log "ERROR! set WEBDAV_TOKEN or WEBDAV_USERNAME/WEBDAV_PASSWORD for authentication."
    exit 1
fi

if [[ -n "$prefix" ]]; then
    prefix="${prefix#/}"
    prefix="${prefix%/}"
    base_url="${base_url%/}/${prefix}"
else
    base_url="${base_url%/}"
fi

package_url="${base_url}/package"
package_url_slash="${package_url}/"

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

if [[ ! -d "$package_root" ]]; then
    log "ERROR! package directory is missing: ${package_root}"
    exit 1
fi

ensure_package_dir() {
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -X MKCOL "${auth_args[@]}" "$package_url_slash")
    case "$status" in
        200|201|204|301|302|307|308|405)
            return 0
            ;;
        *)
            log "ERROR! failed to ensure package directory (${package_url_slash}), http status ${status}"
            return 1
            ;;
    esac
}

remote_exists() {
    local url=$1
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -I -L "${auth_args[@]}" "$url")
    case "$status" in
        200|204)
            return 0
            ;;
        404)
            return 1
            ;;
        401|403)
            log "ERROR! authentication failed for ${url}"
            exit 2
            ;;
        *)
            log "ERROR! unexpected http status ${status} for ${url}"
            return 2
            ;;
    esac
}

list_remote_files() {
    curl -sS -X PROPFIND -H "Depth: 1" "${auth_args[@]}" "$package_url_slash" | python3 - <<'PY'
import sys
import os
import urllib.parse
import xml.etree.ElementTree as ET

data = sys.stdin.read()
if not data.strip():
    sys.exit(0)
try:
    root = ET.fromstring(data)
except Exception:
    sys.exit(0)

for elem in root.iter():
    if not elem.tag.endswith('href'):
        continue
    if not elem.text:
        continue
    path = urllib.parse.unquote(elem.text)
    name = os.path.basename(path.rstrip('/'))
    if name:
        print(name)
PY
}

index=1
log "\nstep $index -- begin upload packages [$(date)]"
ensure_package_dir

for module_name in "${modules[@]}"; do
    index=$((index+1))
    log "\nstep $index -- handle module [${module_name}]"

    package_candidates=("${package_root}/${module_name}-"*.tar.gz)
    if [[ ${#package_candidates[@]} -eq 0 ]]; then
        log "ERROR! package file not found: ${package_root}/${module_name}-*.tar.gz"
        exit 3
    fi
    package_file=$(ls -t "${package_candidates[@]}" | head -n 1)
    filename=$(basename "$package_file")
    remote_file_url="${package_url}/${filename}"

    if remote_exists "$remote_file_url"; then
        log "remote file exists, skip upload: ${filename}"
    else
        log "uploading ${filename}"
        upload_status=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${auth_args[@]}" --data-binary @"$package_file" "$remote_file_url")
        case "$upload_status" in
            200|201|204)
                log "upload success: ${filename}"
                ;;
            401|403)
                log "ERROR! authentication failed during upload: ${filename}"
                exit 4
                ;;
            *)
                log "ERROR! upload failed for ${filename}, http status ${upload_status}"
                exit 4
                ;;
        esac
    fi

    mapfile -t remote_files < <(list_remote_files)
    for remote_name in "${remote_files[@]}"; do
        if [[ "$remote_name" == "$filename" ]]; then
            continue
        fi
        if [[ "$remote_name" == "${module_name}-"*.tar.gz ]]; then
            delete_url="${package_url}/${remote_name}"
            delete_status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${auth_args[@]}" "$delete_url")
            case "$delete_status" in
                200|202|204|404)
                    log "delete old package: ${remote_name}"
                    ;;
                *)
                    log "ERROR! failed to delete ${remote_name}, http status ${delete_status}"
                    exit 5
                    ;;
            esac
        fi
    done
done

index=$((index+1))
log "\nstep $index -- upload packages done. [$(date)]"
