#!/usr/bin/env bash
# fetch-assets.sh — 批量下载站点资产，带重试、超时、content-type 校验与失败清单。
#
# 为什么不直接 for + curl：
#   1. CDN 偶发断流，单次 curl 会静默写下一个 0 字节的 .webp，到 Build 阶段才发现；
#   2. `.png` 的 URL 可能返回 AVIF，肉眼在浏览器里看不出问题，但你的管线会崩；
#   3. 失败必须留下清单，否则你会以为全下完了。
#
# 用法：
#   bash fetch-assets.sh originals.txt public/sites/mysite/assets
#   bash fetch-assets.sh originals.txt ./assets --retries 3 --timeout 90 --flat
#
# 参数：
#   $1            URL 清单文件（一行一个，通常来自 unwrap-image-urls.py）
#   $2            目标目录（自动创建）
#   --retries N   失败重试次数（默认 2）
#   --timeout S   单次超时秒数（默认 60）
#   --flat        全部平铺到目标目录，不保留 URL 路径层级（默认开启）
#   --keep-path   保留 URL 的路径层级（与 --flat 互斥，后出现的生效）

set -uo pipefail

URLS_FILE="${1:-}"
DEST="${2:-}"
RETRIES=2
TIMEOUT=60
FLAT=1

if [[ -z "$URLS_FILE" || -z "$DEST" ]]; then
  echo "用法: bash fetch-assets.sh <urls-file> <dest-dir> [--retries N] [--timeout S] [--keep-path]"
  exit 1
fi
shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --retries) RETRIES="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --flat) FLAT=1; shift ;;
    --keep-path) FLAT=0; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

[[ -f "$URLS_FILE" ]] || { echo "✗ 找不到 URL 清单: $URLS_FILE"; exit 1; }
mkdir -p "$DEST"
FAIL_LIST="$DEST/.failed.txt"
: > "$FAIL_LIST"

# 从 URL 推导文件名：取 basename，去掉 query，非法字符替换为 _
derive_name() {
  local url="$1"
  local base="${url%%\?*}"
  base="${base##*/}"
  [[ -z "$base" || "$base" == "/" ]] && base="asset"
  base="$(printf '%s' "$base" | tr -c 'A-Za-z0-9._-' '_')"
  printf '%s' "$base"
}

ok=0; fail=0
while IFS= read -r url; do
  [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
  if (( FLAT )); then
    out="$DEST/$(derive_name "$url")"
  else
    rel="${url#*://}"; rel="${rel#*/}"
    rel="${rel%%\?*}"
    out="$DEST/$rel"
    mkdir -p "$(dirname "$out")"
  fi

  attempt=0
  while (( attempt <= RETRIES )); do
    code="$(curl -sS -L --max-time "$TIMEOUT" -o "$out" -w '%{http_code}' "$url" 2>/dev/null)"
    [[ -z "$code" ]] && code=000
    if [[ "$code" == "200" && -s "$out" ]]; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  if [[ "$code" == "200" && -s "$out" ]]; then
    ctype="$(file -b --mime-type "$out" 2>/dev/null || echo unknown)"
    size="$(wc -c < "$out" | tr -d ' ')"
    echo "ok   $(basename "$out")  ${size}B  ${ctype}"
    ok=$((ok + 1))
  else
    echo "FAIL $url (http=$code)"
    echo "$url" >> "$FAIL_LIST"
    rm -f "$out"
    fail=$((fail + 1))
  fi
done < "$URLS_FILE"

echo "-----------------------------------------"
echo "成功 $ok · 失败 $fail · 目录 $DEST"
if (( fail > 0 )); then
  echo "失败清单: $FAIL_LIST"
fi
