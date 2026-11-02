# 双开排错手册（Muse 9.0 双开实战沉淀）

## 症状 → 原因 → 修法

| 症状 | 原因 | 修法 |
|---|---|---|
| `open` 报 executable missing | 包里没有 `CFBundleExecutable` 键，改了 BundleID 后系统找不到主程序 | 补 `Add :CFBundleExecutable string <MacOS下主程序名>`，`CFBundleName` 别动 |
| plist 改不动 Permission denied | `cp -R` 保留了只读权限 | `chmod -R u+w <分身>` |
| 程序坞看不到分身 | 用 `nohup` 直接拉二进制，绕过 LaunchServices | 用 `open <.app>` 启动，再右键保留 |
| 两个图标一模一样分不清 | 同一套 AppIcon | 打角标（脚本 `BADGE=2`） |
| 登录转圈后失败，日志满屏 `keychain(-34018)` | 临时签名无钥匙串权限，设备ID/凭证存不下 | `WITH_SHIM=1` 重跑（阶段二） |
| 分身自己升级后包名被改回去 | Sparkle 自动更新覆盖 Info.plist | `defaults write <新ID> SUEnableAutomaticChecks -bool NO`（脚本已做） |
| 分身与原版同账号、一处退出处处退 | 登录票据在系统钥匙串（如 `com.tencent.ima.account`），临时签名分身与原版共读 | `WITH_SHIM=1` 重跑，翻译器给分身独立钥匙串（Muse/WorkBuddy 实测） |
| 翻译器不生效（分身仍读真钥匙串） | 三件套定位：① plist 的 `DYLD_INSERT_LIBRARIES` 值是否带多余 `string `（`Set` 语法无类型字，加了会存成字面量）；② 翻译器日志有无 `INIT` 行（`~/Library/Application Support/<KCSHIM_BUNDLE_ID>/KeychainShim/shim.log`）；③ `KCSHIM_BUNDLE_ID` 是否每家唯一（缺省全叫 `default` 会互串） | 逐个修，`Set` 不加类型字，ID 每家唯一，重签重开 |
| Electron 系改名后启动即 `SIGTRAP` + 日志 `Unable to find helper app` | 源码级实锤（electron v26 `electron_main_delegate_mac.mm:OverrideChildProcessPath`）：按 `Frameworks/<名> Helper.app/Contents/MacOS/<名> Helper`（**含内层可执行文件**）依次试 `ELECTRON_PRODUCT_NAME`（编译期写死）和主包 `CFBundleName`，两次都 miss 才 FATAL。改主名必须同步改 Helper 文件夹名 **+ 内层二进制文件名 + Helper plist 的 `CFBundleExecutable`**；最省事的是**主名别改**（只改包 id + 图标角标 + 数据目录，Dock 靠角标区分） | 主名回原值（Helper 原样不动），或三处同步改名，重签 |
| `lsof` 显示零共享文件，但分身仍同步 | `lsof` 只能看到**一直打开着**的文件；读一次就关的小票据文件（如 `~/.xxx/device-id`）完美隐身 | 用 `open()` 重定向兜底（kcshim 自带 device-id 通用逻辑：凡是以 `/<原数据目录>/device-id` 结尾的一律拐到分身目录），不要信 lsof 的无罪证明 |
| 启动即 `Killed: 9` | 签名证书不受信任，或钥匙串权限 Team 对不上 | 别用证书，直接临时签名 + 翻译器 |
| 分身启动就消失、无 crash（原版在运行时） | `requestSingleInstanceLock()` 单实例锁（锁文件常在硬编码目录，如 `~/.workbuddy/app`） | 别改名，找官方多实例环境变量做隔离（阶段三），`EXTRA_ENV` 注入 |
| 分身启动即 `SIGABRT`，crash 写 `incompatible architecture (have 'arm64', need 'arm64e')` | 主程序是 arm64e 平台二进制（如 TextEdit），翻译器只有 arm64 | 翻译器必须编 universal（arm64+arm64e），且架构无交集时**不得注入**（脚本已做检查） |

## 已证伪的路线（不要重蹈）

1. **自签证书 + entitlements 给钥匙串权限**：死路两条。
   - 无 Team 的证书带 `keychain-access-groups` → 内核启动即 SIGKILL（权限与签名 Team 必须一致）。
   - 自签证书伪造 OU 冒充官方 Team → 系统不认，`TeamIdentifier` 仍是 not set（防冒充设计）。
2. **改 `FBKeychainAccessGroup` / 删 `embedded.provisionprofile`**：分组是硬编码在二进制里的，改配置没用（已实测 `-34018` 照报）。
3. **翻译器里调 `dlsym(RTLD_NEXT, …)` 回落系统**：启动期与 Swift 运行时撞车，主线程 100% 卡死在 `_SwiftDeferredNSDictionary` 桥接里。必须纯文件存储，永不回落。
4. **`spctl` 显示 rejected**：临时签名都这样，无 quarantine 照常跑，不用理。

## 诊断命令

```bash
# 分身钥匙串拦截日志（翻译器）
cat ~/Library/Application\ Support/<新ID>/KeychainShim/shim.log
# 应用自带调试日志（找 login_failed / is_authenticated=true）
grep -o '"message":"[^"]*login_[a-z_]*[^"]*"' ~/Library/Caches/<新ID>/DebugLogs/debug.jsonl | tail
# 卡死抓栈
sample <pid> 3 -file /tmp/s.txt; sed -n '/Call graph/,/^$/p' /tmp/s.txt | head -30
# 确认原应用签名完好
codesign -dv /Applications/<原>.app 2>&1 | grep -E "Identifier|Signature|TeamIdentifier"
```
