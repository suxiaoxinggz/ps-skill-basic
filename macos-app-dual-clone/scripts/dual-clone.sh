#!/bin/bash
# dual-clone.sh — macOS 应用双开一键克隆
# 用法: [WITH_SHIM=1] [BADGE=2] dual-clone.sh <原App路径> <分身名> <新BundleID>
# 示例: dual-clone.sh /Applications/WeChat.app WeChat2 com.tencent.xinWeChat2
#       WITH_SHIM=1 dual-clone.sh /Applications/Muse.app Muse2 com.meta.endo2
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORIG="$1"; NAME="$2"; NEWID="$3"
[ -z "$ORIG" ] || [ -z "$NAME" ] || [ -z "$NEWID" ] && { echo "用法: $0 <原App> <分身名> <新BundleID>"; exit 1; }
[ -d "$ORIG" ] || { echo "找不到 $ORIG"; exit 1; }
DEST="/Applications/${NAME}.app"

if [ "${WITH_SHIM:-0}" = "1" ]; then
  command -v clang >/dev/null 2>&1 || { echo "缺 clang，请先装 Xcode CommandLineTools: xcode-select --install"; exit 1; }
fi

echo "[1/7] 复制..."
pkill -f "${NAME}.app/Contents/MacOS/" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$ORIG" "$DEST"
chmod -R u+w "$DEST"

# 沙盒 App（App Store 下载的）会被系统剥掉 DYLD 注入，翻译器对其无效，提前告知
ORIGBIN=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$ORIG/Contents/Info.plist" 2>/dev/null || true)
[ -n "$ORIGBIN" ] || ORIGBIN=$(find "$ORIG/Contents/MacOS" -maxdepth 1 -type f -exec stat -f "%z:%N" {} + 2>/dev/null | sort -t: -k1 -rn | head -1 | cut -d: -f2-)
[ -n "$ORIGBIN" ] && BASENAME_ORIGBIN="${ORIGBIN##*/}" || BASENAME_ORIGBIN=""
if [ -n "$BASENAME_ORIGBIN" ] && codesign -d --entitlements - "$ORIG/Contents/MacOS/$BASENAME_ORIGBIN" 2>/dev/null | grep -q "app-sandbox"; then
  echo "  ⚠ 原应用是沙盒 App：DYLD 注入会被剥离，WITH_SHIM 翻译器对其无效；"
  echo "  ⚠ 且其数据在 ~/Library/Containers/<旧ID>，分身数据目录行为可能不同。继续基础克隆..."
fi

echo "[2/7] 改包名..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $NEWID" "$DEST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $NAME" "$DEST/Contents/Info.plist"
# Electron 应用：默认把 CFBundleName 改为分身名（独立 userData + 单实例锁）。
# 例外（WorkBuddy 类）：见 SKILL.md，改名会启动即 SIGTRAP，必须 KEEP_BUNDLENAME=1
# 并用 EXTRA_ENV 走官方多实例环境变量分离。
if [ "${KEEP_BUNDLENAME:-0}" != "1" ] && [ -f "$DEST/Contents/Frameworks/Electron Framework.framework/Electron Framework" ] || \
   [ "${KEEP_BUNDLENAME:-0}" != "1" ] && [ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$DEST/Contents/Info.plist" 2>/dev/null)" = "Electron" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $NAME" "$DEST/Contents/Info.plist" && echo "  Electron 应用：CFBundleName=$NAME（独立 userData + 单实例锁）"
fi
if ! /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$DEST/Contents/Info.plist" >/dev/null 2>&1; then
  # 没有 CFBundleExecutable：取 MacOS 下最大的常规文件（通常就是主程序）
  BIGGEST=$(find "$DEST/Contents/MacOS" -maxdepth 1 -type f -exec stat -f "%z:%N" {} + 2>/dev/null | sort -t: -k1 -rn | head -1 | cut -d: -f2-)
  BIN="${BIGGEST##*/}"
  [ -n "$BIN" ] || { echo "找不到可执行文件，退出"; exit 1; }
  /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $BIN" "$DEST/Contents/Info.plist" && echo "  补 CFBundleExecutable=$BIN"
fi

if [ "${WITH_SHIM:-0}" = "1" ]; then
  echo "[3/7] 编译钥匙串翻译器 + 注入启动环境..."
  DYLIB=~/.local/share/mac-app-dual/${NAME}.dylib
  mkdir -p ~/.local/share/mac-app-dual
  clang -dynamiclib -O2 -arch arm64 -arch arm64e -o "$DYLIB" "$SCRIPT_DIR/kcshim.c" -framework Security -framework CoreFoundation -framework IOKit \
    && echo "  dylib=$DYLIB ($(lipo -archs "$DYLIB" 2>/dev/null))"
  # 架构必须相交：arm64e 平台二进制（如 TextEdit）加载不了纯 arm64 dylib，硬注会启动即 SIGABRT
  CLONEBIN=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$DEST/Contents/Info.plist")
  BINARCHS=$(lipo -archs "$DEST/Contents/MacOS/$CLONEBIN" 2>/dev/null || echo arm64)
  OVERLAP=0; for A in $BINARCHS; do lipo -archs "$DYLIB" 2>/dev/null | grep -qw "$A" && OVERLAP=1; done
  if [ "$OVERLAP" != "1" ]; then
    echo "  ⚠ 主程序仅支持 [$BINARCHS]，翻译器无交集：跳过注入（分身仍可用，登录修复不适用）"
    rm -f "$DYLIB"
  else
  /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$DEST/Contents/Info.plist" 2>/dev/null || true
  for K in DYLD_INSERT_LIBRARIES KCSHIM_BUNDLE_ID; do
    /usr/libexec/PlistBuddy -c "Delete :LSEnvironment:$K" "$DEST/Contents/Info.plist" 2>/dev/null || true
  done
  /usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string $DYLIB" "$DEST/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :LSEnvironment:KCSHIM_BUNDLE_ID string $NEWID" "$DEST/Contents/Info.plist"
  fi
else
  echo "[3/7] 跳过翻译器（WITH_SHIM!=1；登录失败报-34018 时重跑并加 WITH_SHIM=1）"
fi

# 通用环境变量注入（直通）：EXTRA_ENV="K1=V1 K2=V2" → LSEnvironment（值不能含空格）
if [ -n "${EXTRA_ENV:-}" ]; then
  echo "[3.5/7] 注入自定义环境..."
  /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$DEST/Contents/Info.plist" 2>/dev/null || true
  for KV in $EXTRA_ENV; do
    K="${KV%%=*}"; V="${KV#*=}"
    /usr/libexec/PlistBuddy -c "Delete :LSEnvironment:$K" "$DEST/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:$K string $V" "$DEST/Contents/Info.plist" && echo "  $K=$V"
  done
fi

if [ -n "${BADGE:-}" ]; then
  echo "[4/7] 打图标角标..."
  # 图标文件名读 CFBundleIconFile（没有则找 Resources 下第一个 .icns；都没有就跳过）
  ICONBASE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$DEST/Contents/Info.plist" 2>/dev/null || true)
  ICON="$DEST/Contents/Resources/${ICONBASE%.icns}.icns"
  [ -f "$ICON" ] || ICON=$(find "$DEST/Contents/Resources" -maxdepth 1 -name '*.icns' 2>/dev/null | head -1)
  if [ -z "$ICON" ]; then
    echo "  跳过（包内无 .icns，现代 App 图标在 Assets.car 里，动不了）"
  else
  python3 - "$ICON" "$BADGE" <<'EOF' 2>/dev/null && echo "  角标OK" || echo "  跳过（缺PIL/sips）"
import sys, os
from PIL import Image, ImageDraw, ImageFont
from subprocess import check_call
src, text = sys.argv[1], sys.argv[2]
check_call(['sips','-s','format','png',src,'--out','/tmp/_badge.png'],
           stdout=open(os.devnull,'w'), stderr=open(os.devnull,'w'))
img = Image.open('/tmp/_badge.png').convert('RGBA')
W,H = img.size; bw = int(W*0.42)
x0,y0 = W-bw-int(W*0.04), H-bw-int(H*0.04); x1,y1 = W-int(W*0.04), H-int(H*0.04)
d = ImageDraw.Draw(img)
d.rounded_rectangle([x0,y0,x1,y1], radius=int(bw*0.22), fill=(20,20,22,255),
                    outline=(255,255,255,255), width=max(2,int(W*0.012)))
try: f = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', int(bw*0.62))
except Exception: f = ImageFont.load_default()
d.text(((x0+x1)//2,(y0+y1)//2), text, font=f, fill=(255,255,255,255), anchor='mm')
os.makedirs('/tmp/_badge.iconset', exist_ok=True)
for n,s in [('icon_16x16',16),('icon_16x16@2x',32),('icon_32x32',32),('icon_32x32@2x',64),
            ('icon_128x128',128),('icon_128x128@2x',256),('icon_256x256',256),
            ('icon_256x256@2x',512),('icon_512x512',512),('icon_512x512@2x',1024)]:
    img.resize((s,s), Image.LANCZOS).save(f'/tmp/_badge.iconset/{n}.png')
check_call(['iconutil','-c','icns','/tmp/_badge.iconset','-o',src])
EOF
  fi
else
  echo "[4/7] 跳过角标（BADGE未设；如需区分图标，设 BADGE=2）"
fi

echo "[5/7] 关分身自动更新 + 重签..."
defaults write "$NEWID" SUEnableAutomaticChecks -bool NO 2>/dev/null || true
codesign --force --deep --sign - "$DEST" && echo "  签名OK"

echo "[6/7] 校验原应用未动..."
codesign -dv "$ORIG" 2>&1 | grep -E "Identifier|Signature" | head -2

echo "[7/7] 完成！(自检哨)" 
if [ "${WITH_SHIM:-0}" = "1" ]; then
  DYLIB=~/.local/share/mac-app-dual/${NAME}.dylib
  [ -f "$DYLIB" ] && echo "  ✓ dylib存在: $DYLIB" || echo "  ✗ dylib缺失，翻译器未生效！"
  /usr/libexec/PlistBuddy -c "Print :LSEnvironment:DYLD_INSERT_LIBRARIES" "$DEST/Contents/Info.plist" 2>/dev/null | grep -q "$DYLIB" \
    && echo "  ✓ 注入已写入plist" || echo "  ✗ plist无注入键，翻译器未生效！"
  echo "  首启分身后查: ~/Library/Application Support/$NEWID/KeychainShim/shim.log 须有 INIT 行，无则回troubleshooting'翻译器不生效'"
fi
echo "  启动: open \"$DEST\""
echo "  然后在程序坞右键分身图标 → 选项 → 在程序坞中保留"
echo "  原版升级后重跑本脚本即可，登录态不受影响"
