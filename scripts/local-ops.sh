#!/usr/bin/env bash
# scripts/local-ops.sh
# Claude-powered local file integration — Shell automation helpers
#
# Usage:
#   ./scripts/local-ops.sh stats  [root_path]
#   ./scripts/local-ops.sh list   [root_path] [extension]
#   ./scripts/local-ops.sh watch  [root_path] [interval_seconds]
#   ./scripts/local-ops.sh report [root_path]
#   ./scripts/local-ops.sh help

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────

ROOT_PATH="${2:-$(pwd)}"
INTERVAL="${3:-5}"
SNAPSHOT_FILE="/tmp/local_ops_snapshot_$$.txt"

# ── Language Map ──────────────────────────────────────────────────────────

declare -A LANG_MAP
LANG_MAP[".m"]="Objective-C"
LANG_MAP[".h"]="Objective-C/C"
LANG_MAP[".swift"]="Swift"
LANG_MAP[".js"]="JavaScript"
LANG_MAP[".ts"]="TypeScript"
LANG_MAP[".sh"]="Shell"
LANG_MAP[".html"]="HTML"
LANG_MAP[".htm"]="HTML"
LANG_MAP[".rb"]="Ruby"
LANG_MAP[".json"]="JSON"
LANG_MAP[".md"]="Markdown"
LANG_MAP[".xml"]="XML"
LANG_MAP[".plist"]="XML/Plist"
LANG_MAP[".xib"]="Interface Builder"
LANG_MAP[".storyboard"]="Interface Builder"
LANG_MAP[".css"]="CSS"

IGNORED_DIRS=("node_modules" ".git" "Pods" "DerivedData" "xcuserdata" "dist" ".build")

# ── Helpers ────────────────────────────────────────────────────────────────

should_ignore() {
  local name="$1"
  for d in "${IGNORED_DIRS[@]}"; do
    [[ "$name" == "$d" ]] && return 0
  done
  return 1
}

get_language() {
  local ext="${1,,}"   # lowercase
  echo "${LANG_MAP[$ext]:-Other}"
}

# Recursively find all files under ROOT_PATH, excluding ignored dirs.
# Prints: size<TAB>ext<TAB>relative_path
collect_files() {
  local root="$1"
  while IFS= read -r -d '' fullpath; do
    local relpath="${fullpath#"$root/"}"
    local fname; fname="$(basename "$fullpath")"

    # Skip hidden
    [[ "$fname" == .* ]] && continue

    # Skip if any path component is ignored
    local skip=false
    IFS='/' read -ra parts <<< "$relpath"
    for part in "${parts[@]}"; do
      if should_ignore "$part"; then
        skip=true
        break
      fi
    done
    "$skip" && continue

    local size; size=$(stat -f%z "$fullpath" 2>/dev/null || stat -c%s "$fullpath" 2>/dev/null || echo 0)
    local ext=".${fname##*.}"
    [[ "$ext" == ".$fname" ]] && ext=""   # no extension
    printf '%s\t%s\t%s\n' "$size" "$ext" "$relpath"
  done < <(find "$root" -type f -print0)
}

# ── Commands ───────────────────────────────────────────────────────────────

cmd_stats() {
  echo ""
  echo "📊 Project Statistics: $ROOT_PATH"
  echo "══════════════════════════════════════════════════"

  local tmp; tmp=$(collect_files "$ROOT_PATH")
  local total_files; total_files=$(echo "$tmp" | wc -l | tr -d ' ')
  local total_bytes; total_bytes=$(echo "$tmp" | awk -F'\t' '{s+=$1}END{print s+0}')

  echo "  Total files : $total_files"
  printf "  Total size  : %.1f KB\n" "$(echo "scale=1; $total_bytes / 1024" | bc)"
  echo ""
  echo "  Language breakdown:"

  # Accumulate per-language totals
  declare -A lang_bytes lang_count
  while IFS=$'\t' read -r size ext _path; do
    local lang; lang=$(get_language "$ext")
    lang_bytes["$lang"]=$(( ${lang_bytes["$lang"]:-0} + size ))
    lang_count["$lang"]=$(( ${lang_count["$lang"]:-0} + 1 ))
  done <<< "$tmp"

  # Print sorted by bytes desc
  for lang in "${!lang_bytes[@]}"; do
    echo "${lang_bytes[$lang]} $lang ${lang_count[$lang]}"
  done | sort -rn | while read -r bytes lang count; do
    local pct; pct=$(echo "scale=1; $bytes * 100 / $total_bytes" | bc)
    local bar_len; bar_len=$(echo "scale=0; $pct / 2" | bc)
    local bar; bar=$(printf '%*s' "$bar_len" '' | tr ' ' '█')
    printf "    %-20s %-25s %s%% (%s files)\n" "$lang" "$bar" "$pct" "$count"
  done

  echo "══════════════════════════════════════════════════"
}

cmd_list() {
  local ext_filter="${3:-}"
  echo ""
  echo "📁 Files in: $ROOT_PATH${ext_filter:+ (filter: $ext_filter)}"
  echo "──────────────────────────────────────────────────"
  collect_files "$ROOT_PATH" | while IFS=$'\t' read -r size ext relpath; do
    if [[ -z "$ext_filter" || "$ext" == "$ext_filter" || "$ext" == ".$ext_filter" ]]; then
      local lang; lang=$(get_language "$ext")
      printf "  %-55s %-15s %s B\n" "$relpath" "$lang" "$size"
    fi
  done
}

cmd_watch() {
  echo "👁  Watching $ROOT_PATH every ${INTERVAL}s …  (Ctrl-C to stop)"

  # Build initial snapshot: path<TAB>mtime
  > "$SNAPSHOT_FILE"
  while IFS=$'\t' read -r _size _ext relpath; do
    local fullpath="$ROOT_PATH/$relpath"
    local mtime; mtime=$(stat -f%m "$fullpath" 2>/dev/null || stat -c%Y "$fullpath" 2>/dev/null || echo 0)
    printf '%s\t%s\n' "$fullpath" "$mtime" >> "$SNAPSHOT_FILE"
  done < <(collect_files "$ROOT_PATH")

  trap 'rm -f "$SNAPSHOT_FILE"; echo ""; echo "⏹  Stopped."; exit 0' INT TERM

  while true; do
    sleep "$INTERVAL"
    local new_snap; new_snap=$(mktemp)

    # Collect fresh snapshot
    while IFS=$'\t' read -r _size _ext relpath; do
      local fullpath="$ROOT_PATH/$relpath"
      local mtime; mtime=$(stat -f%m "$fullpath" 2>/dev/null || stat -c%Y "$fullpath" 2>/dev/null || echo 0)
      printf '%s\t%s\n' "$fullpath" "$mtime" >> "$new_snap"
    done < <(collect_files "$ROOT_PATH")

    # Detect modifications / deletions
    while IFS=$'\t' read -r fpath old_mtime; do
      local new_mtime; new_mtime=$(grep -F "$fpath" "$new_snap" | awk -F'\t' '{print $2}' | head -1)
      if [[ -z "$new_mtime" ]]; then
        echo "  🗑  Deleted : ${fpath#"$ROOT_PATH/"}"
      elif [[ "$new_mtime" != "$old_mtime" ]]; then
        echo "  📝 Modified: ${fpath#"$ROOT_PATH/"}"
      fi
    done < "$SNAPSHOT_FILE"

    # Detect additions
    while IFS=$'\t' read -r fpath _mtime; do
      if ! grep -qF "$fpath" "$SNAPSHOT_FILE"; then
        echo "  ➕ Added   : ${fpath#"$ROOT_PATH/"}"
      fi
    done < "$new_snap"

    mv "$new_snap" "$SNAPSHOT_FILE"
  done
}

cmd_report() {
  echo ""
  echo "Generating report for: $ROOT_PATH"
  cmd_stats
  echo ""
  echo "Report generated at: $(date)"
}

cmd_help() {
  cat <<'EOF'

╔══════════════════════════════════════════════════════╗
║   Claude Local File Integration — Shell Automation  ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  Usage: local-ops.sh <command> [root_path] [opts]    ║
║                                                      ║
║  Commands:                                           ║
║    stats   [root]          Language statistics       ║
║    list    [root] [ext]    List files (opt. filter)  ║
║    watch   [root] [secs]   Watch for file changes    ║
║    report  [root]          Full project report       ║
║    help                    Show this help            ║
║                                                      ║
║  Examples:                                           ║
║    ./scripts/local-ops.sh stats .                    ║
║    ./scripts/local-ops.sh list . .swift              ║
║    ./scripts/local-ops.sh watch . 5                  ║
╚══════════════════════════════════════════════════════╝

EOF
}

# ── Dispatch ───────────────────────────────────────────────────────────────

COMMAND="${1:-help}"

case "$COMMAND" in
  stats)   cmd_stats   ;;
  list)    cmd_list    ;;
  watch)   cmd_watch   ;;
  report)  cmd_report  ;;
  help|--help|-h)  cmd_help ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    cmd_help
    exit 1
    ;;
esac
