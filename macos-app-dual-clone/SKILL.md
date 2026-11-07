---
name: mac-app-dual-clone
description: macOS 应用双开/多开分身（微信双开、Muse双开、MiniMax Code 双开、任何App开小号）。用户说"双开""分身""多开""开小号""第二个微信/XX/MiniMax"时必须用本技能。覆盖复制改包名、重签、程序坞、钥匙串登录失败修复，以及 Electron 应用（如 MiniMax Code）单实例锁/asar 身份与 userData 深度隔离全流程。
---

# macOS 应用双开

把 `/Applications/某App.app` 完整克隆一份改包名独立运行，原应用不动。按症状分阶段处理：**阶段一 基础克隆**（多数 App 够用）→**阶段二 登录修复**（钥匙串 -34018）→**阶段三 Electron 官方多实例开关**（如 WorkBuddy）→**阶段四 Electron 深度隔离**（如 MiniMax Code，asar 身份/userData/单实例锁写死）。

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

脚本已处理常见坑（细节见 `references/troubleshooting.md`），做完后：
1. `open /Applications/<分身>.app` 启动（必须走 `open`，`nohup` 拉二进制程序坞认不出）。
2. 在程序坞找到分身图标 → 右键 → 选项 → 在程序坞中保留。
3. 原版更新后分身不会跟着变，重跑一遍脚本即可（分身的登录态在 `~/Library/Application Support/<新BundleID>`，删 `.app` 不丢）。

**脚本后必查（Electron 应用尤其重要）**：
- `xattr -dr com.apple.quarantine "/Applications/<分身>.app"` 清隔离；若仍有残留可 `xattr -cr` 后重签 `codesign --force --deep --sign -`。
- 检查 `Contents/Frameworks/*Helper*.app/Contents/Info.plist` 的 `CFBundleIdentifier` 是否也已改为新前缀（如 `com.xxx.app2.helper*`）。若仍是旧 ID，批量修正后重签；否则可能出现“打不开/身份冲突/单实例异常”。

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
# 遇到钥匙串 -34018/需独立钥匙串时加 WITH_SHIM=1
```

- `CFBundleName` 必须保持原值（改名即 trap，原因未明、实测稳定复现）。
- `WORKBUDDY_CONFIG_DIR` 做真正的隔离（含 Chromium `userData`/session/log、Singleton/会话/配置等；实测 `--user-data-dir=<CONFIG_DIR>/app`）；`WORKBUDDY_INSTANCE_NUMBER` 顺手区分显示名/deeplink。
- 登录态、聊天数据各自独立，原版零干扰。原版升级后重跑上面命令即可（env 由脚本重建，不会丢）。

**同账号坑（WorkBuddy 实测）**：若分身进程已用独立 `--user-data-dir`/`WORKBUDDY_CONFIG_DIR` 但仍显示原账号，常见原因是**共享文件凭据**不在 config dir 下——如 `~/.workbuddy-key-fallback/connector-keys/*`。仅改 env 不够，需 `WITH_SHIM=1` 并使用更新后的 `scripts/kcshim.c`：它会把 `~/.workbuddy-key-fallback[/...]` 的 `open/openat` 重定向到 `$WORKBUDDY_CONFIG_DIR/workbuddy-key-fallback`（或 `~/.workbuddy-key-fallback-<KCSHIM_BUNDLE_ID>`），避免共用连接器/凭据。更新 shim 后需重编分身 dylib（或重跑 `WITH_SHIM=1` 克隆）并重启分身；若分身此前已用共享凭据登录，**退出登录/清理分身 `app` 会话后重登**才能变为独立账号（见 troubleshooting）。


## 阶段四：Electron 深度隔离（MiniMax Code 类，单实例 + asar 身份/userData 写死）

**适用**：基础克隆后仍“还是原来的账号信息”、原版运行时分身秒退/无新窗口、或进程显示 `--user-data-dir` 指向原版目录（如 `~/Library/Application Support/MiniMax`）。典型案例：**MiniMax Code**（Mavis/Electron，含 `requestSingleInstanceLock()`，且 `dist/main/config/app-identity.js` / `dist/main/index.js` 在运行时决定 App ID、名称与 userData 路径）。

**一键脚本（推荐）**：先完成阶段一（基础克隆）并确保分身 Bundle/Helper/quarantine 正常，再执行 `scripts/minimax-asar-isolate.sh`（参数化 CN/Global、BundleID、userData 名，含 Helper ID 修正、asar 备份、JS 补丁、重打包保留 unpacked、重签）。

```bash
# 中国区分身（示例）
scripts/minimax-asar-isolate.sh "/Applications/MiniMax Code 2.app" --region cn

# 国际版分身（示例）
scripts/minimax-asar-isolate.sh "/Applications/MiniMax Code Global 2.app" --region global

# 自定义（示例）
scripts/minimax-asar-isolate.sh "/Applications/MiniMax Code 2.app" \
  --bundle-id com.minimax.agent.cn2 --userdata-name "MiniMax 2" --product-name "MiniMax Code 2"

# 预检（不写入）
scripts/minimax-asar-isolate.sh "/Applications/MiniMax Code 2.app" --region cn --dry-run
```

**脚本参数**
- `--region cn|global`：预设默认值（`cn` → `com.minimax.agent.cn2` / `MiniMax 2`；`global` → `com.minimax.agent2` / `MiniMax Global 2`），仍可被显式参数覆盖。
- `--bundle-id <ID>`：默认读取分身 `Info.plist` 的 `CFBundleIdentifier`。
- `--userdata-name <NAME>`：必需，或由 `--region` 提供；强制 `~/Library/Application Support/<NAME>` 独立数据目录。
- `--product-name <NAME>`：默认取 `CFBundleDisplayName`/分身名，用于补丁标识与 clone 检测。
- `--no-fix-helpers` / `--no-backup`（不推荐）/ `--dry-run`。前置：`node`/`npx`（`@electron/asar`）。

**脚本步骤**
1. `chmod -R u+w`、清 `com.apple.quarantine`；可选修正 `Frameworks/*Helper*.app` 的 `CFBundleIdentifier` 前缀。
2. 备份 `app.asar`/`app.asar.unpacked`（带时间戳）。
3. 解包 asar（容忍因 `unpacked` 缺跨平台文件导致的非零退出，但必须解出 `dist/main/*` 目标文件）。
4. Node 补丁 `dist/main/config/app-identity.js` + `dist/main/index.js`：检测分身（plist BundleID / execPath 含分身名）后强制独立身份与 `userData`，在单实例/存储初始化前 `app.setPath('userData', ...)` + `mkdir -p`。
5. `asar pack --unpack '{**/*.node,**/*.dylib,**/*.so,**/*.dll,**/spawn-helper,**/rg,**/*.app/**}'` 重打包，替换 `app.asar`+`app.asar.unpacked`，清 quarantine，`codesign --force --deep --sign -`。

**注意**：启发式补丁；若版本升级导致 `dist/main/config/app-identity.js`/`dist/main/index.js` 路径或结构变化，脚本会报未命中，请先 `npx @electron/asar list "<asar>" | grep dist/main` 再调整。重跑 `dual-clone.sh` 会覆盖分身并丢失 asar 补丁；原版升级后应“重新克隆 → 再跑本脚本”。验证：`ps aux | grep "<分身.app>" | grep user-data-dir` 应指向 `~/Library/Application Support/<userdata-name>`。

### 诊断
```bash
# 原版已完全退出后再测
pkill -f "MiniMax Code 2.app"; open "/Applications/MiniMax Code 2.app"; sleep 4
ps aux | grep "MiniMax Code 2.app" | grep user-data-dir
# 若 user-data-dir 仍是原版目录，或 App 复用原账号/单实例退出，则需 asar 补丁
npx --yes @electron/asar extract-file "/Applications/<分身>.app/Contents/Resources/app.asar" dist/main/index.js >/tmp/_i.js && grep requestSingleInstanceLock /tmp/_i.js
```

### 修复要点（MiniMax Code 实测）
1. **先完成阶段一 + Helper Bundle ID 修正 + 清 quarantine + 重签**。
2. **补丁 `app.asar`（核心）**：解包 → 修改运行时身份/数据路径 → 重打包 → 替换 → 重签。
   - `dist/main/config/app-identity.js`：检测分身（从 `process.execPath/../Info.plist` 读 `CFBundleIdentifier`，或匹配分身 `.app` 路径），返回分身独立 `appId`/`appName`/`userDataAppName`。
     - CN 版示例：`com.minimax.agent.cn2`，userData 名如 `MiniMax 2`
     - 国际版示例：`com.minimax.agent2`，userData 名如 `MiniMax Global 2`
   - `dist/main/index.js`：在生产环境、`requestSingleInstanceLock`/存储初始化**之前**强制设置独立 `userData`，如 `~/Library/Application Support/MiniMax 2`（或 `MiniMax Global 2`），并 `mkdir -p`。
3. **asar 重打包保留 unpacked**：`npx @electron/asar extract` 可能因 `app.asar.unpacked` 缺少某些 x64/win 平台文件而报错退出，但**目标 JS 文件常已解出**，可继续补丁。重打包时带 `--unpack '{**/*.node,**/*.dylib,**/*.so,**/*.dll,**/spawn-helper,**/rg,**/*.app/**}'`（按实际调整），并用新生成的 `app.asar.new` + `app.asar.new.unpacked` 替换原 `Resources/app.asar` 与 `app.asar.unpacked`，再重签。
4. **验证**：分身进程应显示独立 `--user-data-dir`（如 `.../Application Support/MiniMax 2` 或 `MiniMax Global 2`），Crashpad/`_productName` 显示分身名；登录态应与原版分离。

### 中国区版 vs 国际版（MiniMax Code）
- **不要混用构建**：分身的登录区域由源 `.app` 的构建/配置决定（`isZh`、`minimax-cn`/`minimax` 协议、后端域名）。
  - 中国区：`CFBundleIdentifier=com.minimax.agent.cn`，URL Scheme 常见 `minimax-cn`
  - 国际版：`CFBundleIdentifier=com.minimax.agent`，URL Scheme 常见 `minimax`
- **从 DMG 安装国际版且不覆盖国内版**：挂载 DMG（只读）→ 检查上述标识确认国际版 → 将 `MiniMax Code.app` 复制为 `/Applications/MiniMax Code Global.app`（不要覆盖 `/Applications/MiniMax Code.app`）→ 推出 DMG → 从 `MiniMax Code Global.app` 克隆出 `MiniMax Code Global 2`（用 `com.minimax.agent2` 等独立 ID）并做阶段四隔离。
- 你之前遇到的 DMG 若 `CFBundleIdentifier` 仍是 `com.minimax.agent.cn`、Scheme 为 `minimax-cn`，则它是中国区版，不是国际版。

### 原版升级后的处理（有 asar 补丁时）
- 分身 **不会** 自动升级；升级只影响原版 `.app`。
- 重新跑 `dual-clone.sh` 会覆盖分身，**asar 深度补丁会丢失**。正确流程：基于**升级后的原版**（或对应区域新版）重新克隆 → 重做 Helper ID/quarantine/重签 → 重做 asar 身份+userData 补丁 → 验证。`~/Library/Application Support/<分身数据目录>` 通常保留，登录态可延续（视应用实现）。

## 铁律（不要踩）

1. `CFBundleName` 保持原值（可执行文件按它查找），只改 `CFBundleIdentifier` + `CFBundleDisplayName`。若应用内部/asar 依赖 `CFBundleName` 做单实例或数据目录，需按阶段三/四单独处理，不能盲改。
2. 原包若没有 `CFBundleExecutable` 键必须补上，否则 `open` 报 executable missing。
3. 复制后先 `chmod -R u+w`（原文件只读，plist 改不了）。
4. 证书签名路线是死路：自签证书带不上钥匙串权限（Team 对不上会被内核直接 SIGKILL），不要浪费时间。
5. 翻译器里**绝不能调 `dlsym`**（启动期和 Swift 运行时撞车，主线程 100% 卡死）。只做纯文件存储，不回落调系统。
6. `spctl` 显示 rejected 对临时签名是正常的，但 **`com.apple.quarantine` 会阻止启动/报错**。优先 `xattr -dr com.apple.quarantine`（必要时 `xattr -cr` + 重签）。
7. 关掉分身的 Sparkle 自动更新（脚本已做），否则更新会把 BundleID 覆盖回去。
