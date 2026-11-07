#!/bin/bash
# minimax-asar-isolate.sh — MiniMax Code (Electron/Mavis) 分身深度隔离
# 解决：克隆后仍复用原账号/原 userData、requestSingleInstanceLock 冲突、asar 内身份写死。
# 用法:
#   ./minimax-asar-isolate.sh "/Applications/MiniMax Code 2.app" --region cn
#   ./minimax-asar-isolate.sh "/Applications/MiniMax Code Global 2.app" --region global
#   ./minimax-asar-isolate.sh <分身.app> --bundle-id com.minimax.agent.cn2 --userdata-name "MiniMax 2" --product-name "MiniMax Code 2"
# 选项:
#   --region cn|global        预设 bundle-id/userdata/product（仍以 plist/参数为准，预设仅作默认）
#   --bundle-id ID            目标分身 Bundle ID（默认读取分身 Info.plist）
#   --userdata-name NAME      ~/Library/Application Support/<NAME>（必需，或由 --region 提供）
#   --product-name NAME       asar 身份显示名/产品名提示（默认取 CFBundleDisplayName 或分身名）
#   --no-fix-helpers          跳过 Frameworks Helper BundleID 修正
#   --no-backup               不备份 asar（不推荐）
#   --dry-run                 仅检查与输出计划
# 前置：node/npx 可用（用于 asar 与 JS 补丁）。
set -euo pipefail

usage() { sed -n '2,16p' "$0"; exit "${1:-1}"; }

APP=""
REGION=""
BUNDLE_ID=""
USERDATA_NAME=""
PRODUCT_NAME=""
FIX_HELPERS=1
BACKUP=1
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --region) REGION="${2:-}"; shift 2 ;;
    --bundle-id) BUNDLE_ID="${2:-}"; shift 2 ;;
    --userdata-name) USERDATA_NAME="${2:-}"; shift 2 ;;
    --product-name) PRODUCT_NAME="${2:-}"; shift 2 ;;
    --no-fix-helpers) FIX_HELPERS=0; shift ;;
    --no-backup) BACKUP=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    -*) echo "未知参数: $1"; usage ;;
    *) [ -z "$APP" ] && APP="$1" || { echo "多余参数: $1"; usage; }; shift ;;
  esac
done

[ -n "$APP" ] || { echo "缺少 <分身.app> 路径"; usage; }
[ -d "$APP" ] || { echo "找不到: $APP"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "缺少 npx/node，请先安装 Node.js"; exit 1; }
command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || { echo "仅支持 macOS"; exit 1; }

INFO="$APP/Contents/Info.plist"
[ -f "$INFO" ] || { echo "找不到 Info.plist: $INFO"; exit 1; }
PLIST_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO" 2>/dev/null || true)
PLIST_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$INFO" 2>/dev/null || /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO" 2>/dev/null || basename "$APP" .app)

# region presets (defaults only)
case "${REGION}" in
  cn)
    : "${BUNDLE_ID:=com.minimax.agent.cn2}"
    : "${USERDATA_NAME:=MiniMax 2}"
    ;;
  global)
    : "${BUNDLE_ID:=com.minimax.agent2}"
    : "${USERDATA_NAME:=MiniMax Global 2}"
    ;;
  "") ;;
  *) echo "无效 --region: $REGION（仅 cn|global）"; exit 1 ;;
esac

BUNDLE_ID="${BUNDLE_ID:-$PLIST_ID}"
PRODUCT_NAME="${PRODUCT_NAME:-$PLIST_NAME}"

[ -n "$BUNDLE_ID" ] || { echo "无法确定 Bundle ID，请用 --bundle-id"; exit 1; }
[ -n "$USERDATA_NAME" ] || { echo "缺少 --userdata-name（或使用 --region cn|global）"; exit 1; }

ASAR="$APP/Contents/Resources/app.asar"
UNPACKED="$APP/Contents/Resources/app.asar.unpacked"
[ -f "$ASAR" ] || { echo "找不到 app.asar: $ASAR"; exit 1; }

echo "== MiniMax asar 深度隔离 =="
echo "APP:          $APP"
echo "Bundle ID:    $BUNDLE_ID (plist: ${PLIST_ID:-?})"
echo "userData:     ~/Library/Application Support/$USERDATA_NAME"
echo "Product name: $PRODUCT_NAME"
echo "asar:         $ASAR"
[ "$DRY_RUN" = "1" ] && { echo "[dry-run] 仅检查，不写入"; }

run() { if [ "$DRY_RUN" = "1" ]; then echo "+ $*"; else eval "$@"; fi; }

# 0) chmod/quarantine/helpers (prereqs)
run "chmod -R u+w \"$APP\""
run "xattr -dr com.apple.quarantine \"$APP\" 2>/dev/null || true"

if [ "$FIX_HELPERS" = "1" ] && [ -d "$APP/Contents/Frameworks" ]; then
  echo "[1/5] 修正 Helper Bundle ID 前缀..."
  OLD_PREFIX=""
  # infer old prefix from main app name heuristics? safer: only fix helpers whose id does not start with target bundle id
  while IFS= read -r -d '' HP; do
    HID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$HP" 2>/dev/null || true)
    [ -z "$HID" ] && continue
    case "$HID" in
      "$BUNDLE_ID"*) continue ;;
    esac
    # replace leading known minimax prefixes to target prefix, keep suffix
    NEW_HID=""
    for PFX in com.minimax.agent.cn com.minimax.agent; do
      case "$HID" in
        "$PFX"*) NEW_HID="$BUNDLE_ID${HID#$PFX}"; break ;;
      esac
    done
    if [ -z "$NEW_HID" ]; then
      # generic: if contains old plist prefix, swap
      if [ -n "$PLIST_ID" ] && [ "$PLIST_ID" != "$BUNDLE_ID" ]; then
        case "$HID" in "$PLIST_ID"*) NEW_HID="$BUNDLE_ID${HID#$PLIST_ID}" ;; esac
      fi
    fi
    if [ -n "$NEW_HID" ]; then
      echo "  $HID -> $NEW_HID"
      if [ "$DRY_RUN" != "1" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $NEW_HID" "$HP" 2>/dev/null || true
      fi
    fi
  done < <(find "$APP/Contents/Frameworks" -path "*Helper*.app/Contents/Info.plist" -print0 2>/dev/null)
else
  echo "[1/5] 跳过 Helper 修正"
fi

# 1) backup
TS=$(date +%Y%m%d-%H%M%S)
if [ "$BACKUP" = "1" ]; then
  echo "[2/5] 备份 asar..."
  if [ "$DRY_RUN" != "1" ]; then
    [ ! -f "$ASAR.bak-$TS" ] && cp "$ASAR" "$ASAR.bak-$TS"
    [ -d "$UNPACKED" ] && [ ! -e "$UNPACKED.bak-$TS" ] && cp -R "$UNPACKED" "$UNPACKED.bak-$TS"
  fi
fi

# 2) extract (asar may exit non-zero if unpacked refs missing; check target files)
TMP=$(mktemp -d /tmp/minimax-asar.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
echo "[3/5] 解包 asar（允许 unpacked 缺失类非零退出）..."
if [ "$DRY_RUN" != "1" ]; then
  set +e
  npx --yes @electron/asar extract "$ASAR" "$TMP/app" 2>"$TMP/extract.err"
  EX=$?
  set -e
  [ -f "$TMP/app/dist/main/index.js" ] || [ -f "$TMP/app/dist/main/config/app-identity.js" ] || {
    echo "解包失败且未找到目标 JS (exit=$EX)。错误摘要："; tail -12 "$TMP/extract.err" || true
    echo "请确认这是 MiniMax Code 的 app.asar；可尝试手动: npx @electron/asar list \"$ASAR\" | grep dist/main"
    exit 1
  }
fi

# 3) patch with node
echo "[4/5] 补丁身份/userData..."
PATCHER="$TMP/patch.js"
cat > "$PATCHER" <<'NODE'
const fs = require('fs');
const path = require('path');
const root = process.argv[2];
const bundleId = process.argv[3];
const userDataName = process.argv[4];
const productName = process.argv[5];
let changed = [];

function patchFile(rel, fn) {
  const p = path.join(root, rel);
  if (!fs.existsSync(p)) { console.log('SKIP_MISSING', rel); return; }
  const src = fs.readFileSync(p, 'utf8');
  const out = fn(src, rel);
  if (out !== src) { fs.writeFileSync(p, out); changed.push(rel); console.log('PATCHED', rel); }
  else console.log('NOCHANGE', rel);
}

const marker = `/* minimax-asar-isolate:${bundleId} */`;

patchFile('dist/main/config/app-identity.js', (s, rel) => {
  if (s.includes(marker)) return s;
  // inject override: if running from clone bundle/app, return clone identity
  const inject = `${marker}
;(() => { try {
  const fs = require('fs'); const path = require('path');
  const plist = path.resolve(process.execPath, '../../Info.plist');
  let bid = '';
  try { const t = fs.readFileSync(plist,'utf8'); const m = t.match(/<key>CFBundleIdentifier<\\/key>\\s*<string>([^<]+)<\\/string>/); if (m) bid = m[1]; } catch {}
  const isClone = bid === ${JSON.stringify(bundleId)} || process.execPath.includes(${JSON.stringify(productName + '.app')});
  if (!isClone) return;
  const mod = module.exports;
  const ud = ${JSON.stringify(userDataName)};
  const pn = ${JSON.stringify(productName)};
  const bid2 = ${JSON.stringify(bundleId)};
  const patchObj = (o) => { if(!o||typeof o!=='object') return o; for (const k of Object.keys(o)) { const lk=k.toLowerCase(); if(lk.includes('userid')||lk==='userdataappname'||lk==='userdatadirname') o[k]=ud; if(lk.includes('appid')||lk==='id'||lk==='bundleid'||lk==='identifier') { if(typeof o[k]==='string' && o[k].includes('minimax')) o[k]=bid2; } if(lk.includes('name') && typeof o[k]==='string' && (o[k].includes('MiniMax')||o[k].includes('Mavis'))) o[k]=pn; } return o; };
  if (mod && typeof mod === 'object') { patchObj(mod); if (mod.default) patchObj(mod.default); }
  const wrap = (fn) => typeof fn==='function' ? (...a)=>patchObj(fn(...a)) : fn;
  for (const k of ['getAppIdentity','getIdentity','default']) if (typeof mod[k]==='function') mod[k]=wrap(mod[k]);
} catch(e){} })();
`;
  // append at end to override exports; keep original
  return s + '\n' + inject;
});

patchFile('dist/main/index.js', (s, rel) => {
  if (s.includes(marker)) return s;
  // force userData early (before single-instance/storage init) when clone
  const inject = `${marker}
;(() => { try {
  const { app } = require('electron'); const fs = require('fs'); const path = require('path'); const os = require('os');
  const plist = path.resolve(process.execPath, '../../Info.plist');
  let bid = '';
  try { const t = fs.readFileSync(plist,'utf8'); const m = t.match(/<key>CFBundleIdentifier<\\/key>\\s*<string>([^<]+)<\\/string>/); if (m) bid = m[1]; } catch {}
  const isClone = bid === ${JSON.stringify(bundleId)} || process.execPath.includes(${JSON.stringify(productName + '.app')});
  if (isClone) {
    const ud = path.join(os.homedir(), 'Library', 'Application Support', ${JSON.stringify(userDataName)});
    try { fs.mkdirSync(ud, { recursive: true }); } catch {}
    try { app.setPath('userData', ud); } catch {}
    try { app.setName(${JSON.stringify(productName)}); } catch {}
  }
} catch(e){} })();
`;
  // prefer insertion near top after requires; fallback prepend
  const reqEnd = s.indexOf('\n');
  if (/requestSingleInstanceLock/.test(s)) {
    const idx = s.indexOf('requestSingleInstanceLock');
    const before = s.lastIndexOf('\n', idx);
    if (before > 100) return s.slice(0, before) + '\n' + inject + s.slice(before);
  }
  return inject + '\n' + s;
});

if (changed.length === 0) { console.error('ERROR: no files patched'); process.exit(2); }
console.log('DONE', changed.join(','));
NODE

if [ "$DRY_RUN" != "1" ]; then
  node "$PATCHER" "$TMP/app" "$BUNDLE_ID" "$USERDATA_NAME" "$PRODUCT_NAME"
fi

# 4) repack
echo "[5/5] 重打包 asar、替换并重签..."
NEW_ASAR="$TMP/app.asar.new"
if [ "$DRY_RUN" != "1" ]; then
  # preserve unpacked natives
  npx --yes @electron/asar pack "$TMP/app" "$NEW_ASAR" --unpack '{**/*.node,**/*.dylib,**/*.so,**/*.dll,**/spawn-helper,**/rg,**/*.app/**}'
  mv "$NEW_ASAR" "$ASAR"
  if [ -d "$TMP/app.asar.new.unpacked" ]; then
    rm -rf "$UNPACKED"
    mv "$TMP/app.asar.new.unpacked" "$UNPACKED"
  fi
  # quarantine again (some ops can re-add attrs rarely) and deep sign
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  codesign --force --deep --sign - "$APP"
fi

echo "完成。验证："
echo "  1) 原版完全退出后执行: open \"$APP\"; sleep 5"
echo "  2) ps aux | grep \"$(basename "$APP")\" | grep user-data-dir"
echo "  预期 user-data-dir 指向: ~/Library/Application Support/$USERDATA_NAME"
echo "  若仍复用原账号/单实例，请检查 asar 路径结构与补丁匹配（npx @electron/asar list \"$ASAR\" | grep dist/main）。"