---
name: mac-app-dual-clone
description: macOS 应用双开/多开分身（微信双开、Muse双开、任何App开小号）。用户说"双开""分身""多开""开小号""第二个微信/XX"时必须用本技能。覆盖复制改包名、重签、程序坞、钥匙串登录失败修复全流程。
---

# macOS 应用双开

把 `/Applications/某App.app` 完整克隆一份改包名独立运行，原应用不动。分两个阶段：**基础克隆**（对微信类够用）→**登录修复**（Muse 类钥匙串报错时才需要）。

## 前置条件

- macOS + `xcode-select --install`（阶段二编译翻译器要 `clang`；脚本跑之前会自己检查，缺了直接报错退出，不会留半成品）。
- `python3 + PIL` 仅角标需要，缺了自动跳过。
- 局限：沙盒 App（App Store 下载的）会被系统剥掉 DYLD 注入，翻译器无效；现代 App 图标在 `Assets.car` 里、无 `.icns` 时角标自动跳过。脚本遇到这两种情况都会明说。

## 阶段一：基础克隆（直接跑脚本）

```bash
scripts/dual-clone.sh /Applications/WeChat.app WeChat2 com.tencent.xinWeChat2
# 用法: dual-clone.sh <原App路径> <分身名> <新BundleID> [选项]
#   WITH_SHIM=1   登录失败时才加（见阶段二）
#   BADGE=2       给分身图标打角标（需 python3+PIL，缺了自动跳过）
```

脚本已处理全部坑（细节见 `references/troubleshooting.md`），做完后：
1. `open /Applications/<分身>.app` 启动（必须走 `open`，`nohup` 拉二进制程序坞认不出）。
2. 在程序坞找到分身图标 → 右键 → 选项 → 在程序坞中保留。
3. 原版更新后分身不会跟着变，重跑一遍脚本即可（分身的登录态在 `~/Library/Application Support/<新BundleID>`，删 `.app` 不丢）。

## 阶段二：分身登录失败才看（钥匙串 -34018）

**症状**：分身能启动，登录时转圈后失败。去 `~/Library/Caches/<新BundleID>/` 找 `DebugLogs/*.jsonl`，看到大量 `keychain(-34018)`（= 缺钥匙串权限，临时签名通病）即确诊。

**修法**：`WITH_SHIM=1 scripts/dual-clone.sh ...` 重跑。脚本会编译 `scripts/kcshim.c`（钥匙串翻译器：拦截分身的钥匙串调用，存到它自己的独立文件 `~/Library/Application Support/<新BundleID>/KeychainShim/store.plist`，不碰系统钥匙串），并通过 `LSEnvironment` 注入，保证从程序坞启动也生效。

**验证**：登录成功后 `KeychainShim/shim.log` 应出现 `ADD ... rc=0`，应用日志不再出现 `-34018`，且有 `login_succeeded / is_authenticated=true`。

## 阶段三：Electron 应用分身秒退（WorkBuddy 类）

**症状**：分身启动就消失，无 crash（原版在运行时）→ 代码里有 `requestSingleInstanceLock()`；若手贱改了 `CFBundleName` 则升级成启动即 `SIGTRAP` crash（4 次实测，改回去即恢复）。

**先找官方多实例开关**（别急着改名）：解包 asar（`npx asar extract-file <包> main/<paths类>.js`），看单实例锁/配置目录认什么环境变量。WorkBuddy 的答案：

```bash
KEEP_BUNDLENAME=1 EXTRA_ENV="WORKBUDDY_INSTANCE_NUMBER=2 WORKBUDDY_CONFIG_DIR=/Users/xxx/.workbuddy-2" \
  scripts/dual-clone.sh /Applications/WorkBuddy.app WorkBuddy2 com.tencent.workbuddy.mac2
```

- `CFBundleName` 必须保持原值（改名即 trap，原因未明、实测稳定复现）。
- `WORKBUDDY_CONFIG_DIR` 做真正的隔离（含 Singleton 锁、会话、配置）；`WORKBUDDY_INSTANCE_NUMBER` 顺手区分显示名/deeplink。
- 登录态、聊天数据各自独立，原版零干扰。原版升级后重跑上面命令即可（env 由脚本重建，不会丢）。

## 铁律（不要踩）

1. `CFBundleName` 保持原值（可执行文件按它查找），只改 `CFBundleIdentifier` + `CFBundleDisplayName`。
2. 原包若没有 `CFBundleExecutable` 键必须补上，否则 `open` 报 executable missing。
3. 复制后先 `chmod -R u+w`（原文件只读，plist 改不了）。
4. 证书签名路线是死路：自签证书带不上钥匙串权限（Team 对不上会被内核直接 SIGKILL），不要浪费时间。
5. 翻译器里**绝不能调 `dlsym`**（启动期和 Swift 运行时撞车，主线程 100% 卡死）。只做纯文件存储，不回落调系统。
6. `spctl` 显示 rejected 对临时签名是正常的（没 quarantine 就能跑），不用管。
7. 关掉分身的 Sparkle 自动更新（脚本已做），否则更新会把 BundleID 覆盖回去。
