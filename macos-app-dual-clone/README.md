# macOS App Dual Clone

把 `/Applications/某App.app` 完整克隆一份、改包名独立运行，原应用零改动。解决 macOS 上"双开 / 分身 / 多开 / 开小号"的完整链路，包括系统层面的两个硬坑：**钥匙串权限**和**单实例锁**。

## Overview

三阶段递进，前一个阶段够用就不必往下走：

1. **Phase 1: 基础克隆** — 复制 `.app`、改 `CFBundleIdentifier` + `CFBundleDisplayName`、`chmod -R u+w`、临时重签、关掉 Sparkle 自动更新。对微信类应用直接可用。
2. **Phase 2: 钥匙串修复（`keychain(-34018)`）** — 临时签名带不上钥匙串 entitlement，登录转圈后失败。脚本编译 `scripts/kcshim.c` 拦截分身钥匙串调用，落到分身自己的 `KeychainShim/store.plist`，通过 `LSEnvironment` 注入，从程序坞启动也生效。
3. **Phase 3: Electron 秒退（`requestSingleInstanceLock`）** — 找官方多实例开关做隔离，而不是硬改 `CFBundleName`（实测改名会触发启动即 `SIGTRAP`）。

## Usage

```bash
# Phase 1：基础克隆
scripts/dual-clone.sh /Applications/WeChat.app WeChat2 com.tencent.xinWeChat2

# Phase 2：登录失败才加
WITH_SHIM=1 scripts/dual-clone.sh /Applications/WeChat.app WeChat2 com.tencent.xinWeChat2

# Phase 3：Electron 应用（保持 BundleName，用官方 env 隔离）
KEEP_BUNDLENAME=1 EXTRA_ENV="WORKBUDDY_INSTANCE_NUMBER=2 WORKBUDDY_CONFIG_DIR=$HOME/.workbuddy-2" \
  scripts/dual-clone.sh /Applications/WorkBuddy.app WorkBuddy2 com.tencent.workbuddy.mac2
```

启动必须走 `open /Applications/<分身>.app`（`nohup` 拉二进制程序坞认不出）。原版更新后重跑同一命令即可，分身的登录态在 `~/Library/Application Support/<新BundleID>`，删 `.app` 不丢。

## Requirements

- macOS
- `xcode-select --install`（Phase 2 编译 shim 需要 `clang`；脚本会自检，缺失直接报错退出，不留半成品）
- `python3` + `PIL`（仅图标角标需要，缺失自动跳过）

## Limitations

- **沙盒 App（App Store 下载）**：系统会剥掉 DYLD 注入，Phase 2 翻译器无效。
- **无 `.icns` 的 App**：现代 App 图标在 `Assets.car` 里，角标自动跳过。
- **证书签名路线是死路**：自签证书 Team 对不上会被内核直接 SIGKILL，不要浪费时间。

## Files

| 文件 | 说明 |
|---|---|
| `SKILL.md` | 三阶段完整流程 + 7 条铁律 |
| `scripts/dual-clone.sh` | 一键克隆改包名重签（141 行） |
| `scripts/kcshim.c` | 钥匙串翻译器 C 源码 |
| `references/troubleshooting.md` | 踩坑记录 |

## Installation

```bash
git clone https://github.com/suxiaoxinggz/ps-skill-basic.git
cp -r ps-skill-basic/macos-app-dual-clone ~/.claude/skills/   # Claude Code / Cursor
cp -r ps-skill-basic/macos-app-dual-clone ~/.agents/skills/   # 通用 agents 目录
```

## Verified On

微信、Muse（Meta AI）、WorkBuddy。WorkBuddy 的 `CFBundleName` 改名 → `SIGTRAP` 崩溃实测复现 4 次，改回即恢复。
