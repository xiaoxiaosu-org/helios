#!/usr/bin/env bash
set -euo pipefail

wf_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

wf_now_date() {
  date -u +"%Y-%m-%d"
}

wf_now_compact() {
  date -u +"%Y%m%dT%H%M%SZ"
}

wf_log() {
  local prefix="[workflow]"
  if [ "${WF_TD_ID:-}" != "" ]; then
    prefix="[workflow][${WF_TD_ID}]"
  fi
  echo "${prefix}[$(wf_now)] $*"
}

wf_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

wf_map_file() {
  echo "docs/02-架构/执行计划/workflow-map.yaml"
}

wf_ensure_map_exists() {
  local f
  f="$(wf_map_file)"
  if [ ! -f "${f}" ]; then
    wf_log "缺少 workflow map：${f}" >&2
    exit 1
  fi
}

wf_get_record_block() {
  local td_id="$1"
  local map_file
  map_file="$(wf_map_file)"

  awk -v td="${td_id}" '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    /^[[:space:]]*-[[:space:]]*td_id:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*td_id:[[:space:]]*/, "", line)
      line=trim(line)
      if (line == td) {
        in_block=1
      } else if (in_block) {
        exit
      } else {
        in_block=0
      }
    }
    in_block { print }
  ' "${map_file}"
}

wf_get_field() {
  local td_id="$1"
  local field="$2"
  local block
  block="$(wf_get_record_block "${td_id}")"
  if [ -z "${block}" ]; then
    return 1
  fi

  echo "${block}" | awk -v key="${field}" '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    $0 ~ "^[[:space:]]*"key":[[:space:]]*" {
      line=$0
      sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "", line)
      line=trim(line)
      gsub(/^"|"$/, "", line)
      print line
      exit
    }
  '
}

wf_split_semicolon() {
  # shellcheck disable=SC2034
  local _input="$1"
  IFS=';' read -r -a WF_ITEMS <<< "${_input}"
}

wf_artifact_dir() {
  local td_id="$1"
  local run_id
  run_id="$(wf_now_compact)-$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
  local out_dir="artifacts/workflow/${td_id}/${run_id}"
  mkdir -p "${out_dir}"
  echo "${out_dir}"
}

wf_update_td_open_row() {
  local td_id="$1"
  local new_status="$2"
  local new_date="$3"
  local note_suffix="${4:-}"
  local target_file="$5"
  local tmp
  tmp="$(mktemp)"

  awk -F'|' -v OFS='|' \
    -v td="${td_id}" -v st="${new_status}" -v d="${new_date}" -v suffix="${note_suffix}" '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    /^## 在制技术债/ { section="open"; print; next }
    /^## 已完成/ { section="done"; print; next }
    section == "open" && $0 ~ /^\| TD-[0-9]{3} / {
      row_id=trim($2)
      if (row_id == td) {
        $7=" " st " "
        $8=" " d " "
        if (suffix != "") {
          note=trim($9)
          if (note == "" || note == "-") {
            note=suffix
          } else {
            note=note "；" suffix
          }
          $9=" " note " "
        }
      }
    }
    { print }
  ' "${target_file}" > "${tmp}"

  mv "${tmp}" "${target_file}"
}

wf_row_exists_in_done() {
  local td_id="$1"
  local target_file="$2"
  awk -F'|' -v td="${td_id}" '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    /^## 已完成/ { section="done"; next }
    section == "done" && $0 ~ /^\| TD-[0-9]{3} / {
      if (trim($2) == td) {
        found=1
      }
    }
    END { exit(found ? 0 : 1) }
  ' "${target_file}"
}

wf_help() {
  cat <<'EOF'
用法：
  scripts/workflow/start.sh TD-001
  scripts/workflow/progress.sh TD-001
  scripts/workflow/close.sh TD-001
  scripts/workflow/td-list.sh [open|done|all]
  scripts/workflow/td-add.sh --title ... --impact ... --priority ... --acceptance ... --cap CAP-XXX
EOF
}
