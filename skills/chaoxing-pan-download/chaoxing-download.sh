#!/usr/bin/env bash
# 超星网盘预览链接 -> 直接下载
# 用法: bash chaoxing-download.sh "<预览链接>" [输出文件名]
set -euo pipefail

URL="${1:?用法: chaoxing-download.sh <预览链接> [输出文件名]}"
OUT="${2:-}"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
REFERER="https://pan-yz.chaoxing.com/"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "[1/3] 抓取预览页..."
curl -sS -L -A "$UA" "$URL" -o "$TMP"

# 提取直链
DL_URL="$(grep -oE "'download':[[:space:]]*'https?://[^']+'" "$TMP" | head -1 | sed -E "s/.*'(https?:\/\/[^']+)'.*/\1/")"
if [ -z "$DL_URL" ]; then
  echo "错误: 页面中未找到 download 直链（链接可能已失效或需登录）" >&2
  exit 1
fi
echo "[2/3] 找到直链"

# 决定输出文件名
if [ -z "$OUT" ]; then
  OUT="$(grep -oE 'fileInfoNameInput" value="[^"]*"' "$TMP" | head -1 | sed -E 's/.*value="([^"]*)".*/\1/')"
fi
if [ -z "$OUT" ]; then
  OUT="$(printf '%s' "$DL_URL" | grep -oE 'fn=[^&]+' | head -1 | sed 's/^fn=//')"
fi
if [ -z "$OUT" ]; then
  OUT="chaoxing_download_$(date +%s)"
fi

echo "[3/3] 下载 -> $OUT"
curl -sS -L -A "$UA" -e "$REFERER" "$DL_URL" -o "$OUT"

echo "完成: $OUT ($(wc -c < "$OUT") bytes)"
