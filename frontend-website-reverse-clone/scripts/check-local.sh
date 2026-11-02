#!/usr/bin/env bash
# check-local.sh — 本地服务健康检查。
#
# 为什么需要它：
#   shell 里常有 http_proxy / https_proxy 环境变量，curl localhost 会走代理，
#   代理回一个 502，你会误判成"服务没起来"，然后花半小时去查一个不存在的 bug。
#   实测踩过：next start 日志明明 Ready，curl 却一直 502。
#
# 用法：
#   bash check-local.sh 3100
#   bash check-local.sh 3000 --path /about --wait 20

set -uo pipefail

PORT="${1:-3000}"
PATH_SPEC="/"
WAIT=0

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) PATH_SPEC="$2"; shift 2 ;;
    --wait) WAIT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

URL="http://127.0.0.1:${PORT}${PATH_SPEC}"

if (( WAIT > 0 )); then
  echo "等待 ${URL} 就绪（最多 ${WAIT}s）…"
  for (( i=0; i<WAIT; i++ )); do
    code="$(curl -sS --noproxy '*' -o /dev/null -w '%{http_code}' --max-time 3 "$URL" 2>/dev/null)"
    [[ -z "$code" ]] && code=000
    if [[ "$code" =~ ^(200|30[0-9])$ ]]; then
      echo "✓ ${WAIT}s 内就绪（HTTP $code）"
      exit 0
    fi
    sleep 1
  done
  echo "✗ ${WAIT}s 内未就绪（最后 HTTP $code）"
  exit 1
fi

code="$(curl -sS --noproxy '*' -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null)"
[[ -z "$code" ]] && code=000
echo "HTTP $code  ${URL}"

if [[ "$code" == "000" ]]; then
  echo "→ 完全连不上。检查端口是否真的在监听："
  echo "    lsof -i :${PORT}"
elif [[ "$code" == "502" ]]; then
  echo "→ 502 通常是代理干扰。本脚本已用 --noproxy '*'，若仍 502 检查服务日志。"
fi

# 顺便报告谁占着端口
owner="$(lsof -ti tcp:"${PORT}" 2>/dev/null | head -3)"
if [[ -n "$owner" ]]; then
  echo "→ 端口占用 PID: ${owner}"
else
  echo "→ 端口 ${PORT} 无进程监听"
fi
