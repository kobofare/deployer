#!/usr/bin/env bash
# download latest module packages from WebDAV to /opt/package
# haiqinma - 20260205 - first version

set -euo pipefail
shopt -s nullglob

LOGFILE_PATH="/opt/logs"
LOGFILE_NAME="download-packages.log"
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
code_root="/root/code"
base_url="https://webdav.yeying.pub"
prefix=""

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

base_url="${WEBDAV_BASE_URL:-$base_url}"
prefix="${WEBDAV_PREFIX:-$prefix}"

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

mkdir -p "$package_root"

list_remote_files() {
    local response status body
    response=$(curl -sS -X PROPFIND -H "Depth: 1" "${auth_args[@]}" "$package_url_slash" -w "\n%{http_code}")
    status="${response##*$'\n'}"
    body="${response%$'\n'*}"
    case "$status" in
        200|207)
            ;;
        401|403)
            log "ERROR! authentication failed for ${package_url_slash}"
            exit 2
            ;;
        404)
            log "ERROR! package directory not found: ${package_url_slash}"
            exit 3
            ;;
        *)
            log "ERROR! failed to list package directory (${package_url_slash}), http status ${status}"
            exit 3
            ;;
    esac

    printf '%s' "$body" | python3 -c '
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

seen = set()
def emit(name):
    if not name or name in seen:
        return
    seen.add(name)
    print(name)

for elem in root.iter():
    if elem.text is None:
        continue
    text = elem.text.strip()
    if not text:
        continue
    if elem.tag.endswith("displayname"):
        emit(text)
        continue
    if elem.tag.endswith("href"):
        parsed = urllib.parse.urlparse(text)
        path = parsed.path if parsed.scheme else text
        path = urllib.parse.unquote(path)
        name = os.path.basename(path.rstrip("/"))
        emit(name)
'
}

index=1
log "\nstep $index -- begin download packages [$(date)]"

mapfile -t all_remote_files < <(list_remote_files)
log "remote files count: ${#all_remote_files[@]}"
if [[ ${#all_remote_files[@]} -gt 0 ]]; then
    printf '%s\n' "${all_remote_files[@]}" | tee -a "$LOGFILE" >/dev/null
fi

for module_name in "${modules[@]}"; do
    index=$((index+1))
    module_name="${module_name//$'\r'/}"
    module_name="${module_name#"${module_name%%[![:space:]]*}"}"
    module_name="${module_name%"${module_name##*[![:space:]]}"}"
    if [[ -z "$module_name" ]]; then
        log "\nstep $index -- skip empty module name"
        continue
    fi
    log "\nstep $index -- handle module [${module_name}]"

    matches=()
    for remote_name in "${all_remote_files[@]}"; do
        if [[ "$remote_name" == "${module_name}-"*.tar.gz ]]; then
            matches+=("$remote_name")
        fi
    done
    if [[ ${#matches[@]} -eq 0 ]]; then
        log "ERROR! no remote package found for ${module_name} in ${package_url_slash}"
        exit 4
    fi

    latest=$(printf '%s\n' "${matches[@]}" | sort | tail -n 1)
    remote_file_url="${package_url}/${latest}"
    local_file="${package_root}/${latest}"

    if [[ -f "$local_file" ]]; then
        log "local latest package already exists: ${local_file}"
    else
        tmpfile=$(mktemp "/tmp/${module_name}_package_XXXXXX")
        download_status=$(curl -sS -o "$tmpfile" -w "%{http_code}" "${auth_args[@]}" "$remote_file_url")
        case "$download_status" in
            200|206)
                mv "$tmpfile" "$local_file"
                log "download success: ${local_file}"
                ;;
            401|403)
                rm -f "$tmpfile"
                log "ERROR! authentication failed during download: ${remote_file_url}"
                exit 5
                ;;
            404)
                rm -f "$tmpfile"
                log "ERROR! remote file not found: ${remote_file_url}"
                exit 5
                ;;
            *)
                rm -f "$tmpfile"
                log "ERROR! download failed for ${remote_file_url}, http status ${download_status}"
                exit 5
                ;;
        esac
    fi

    old_packages=("${package_root}/${module_name}-"*.tar.gz)
    for old_pkg in "${old_packages[@]}"; do
        if [[ "$old_pkg" != "$local_file" ]]; then
            rm -f "$old_pkg"
            log "delete old local package: ${old_pkg}"
        fi
    done

    module_dir="${code_root}/${module_name}"
    upgrade_script="${module_dir}/scripts/upgrade_current_env.sh"
    if [[ ! -d "$module_dir" ]]; then
        log "ERROR! code directory is missing: ${module_dir}"
        continue
    fi
    if [[ ! -f "$upgrade_script" ]]; then
        log "ERROR! upgrade script is missing: ${upgrade_script}"
        continue
    fi
    log "run upgrade script for ${module_name}"
    if ! (cd "$module_dir" && bash scripts/upgrade_current_env.sh >> "$LOGFILE" 2>&1); then
        log "ERROR! upgrade script failed for ${module_name}"
        exit 7
    fi
done

index=$((index+1))
log "\nstep $index -- download packages done. [$(date)]"
