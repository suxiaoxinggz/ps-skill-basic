# Error Log — 采集与环境踩坑

> 来源：atypica.ai 克隆实操（2026-10-22）及后续复用。
> 设计与施工类的坑（悬浮条 sticky、React lint、视觉偏差）见
> `atypica-editorial/references/error-log.md`；本文件专注**采集与环境**。

## 目录

- #1 整页截图对滚动触发站点基本全黑
- #2 系统 python3 缺 Pillow + cwd 漂移
- #3 shell 代理导致本地 502 误判
- #4 node_modules 依赖损坏
- #5 后台服务用 nohup 起不来
- #6 一次性 dump 两万字文案被静默截断
- #7 资产 URL 没还原，下下来一堆转码图
- #8 视频缺 muted/playsInline 导致不自动播放
- #9 付费字体硬加载
- #10 已知不可消除的差异（声明模板）

---

## #1 整页截图对滚动触发站点基本全黑

- **现象**：`screenshot({ fullPage: true })` 得到 10007px 长图，中部 6 段纯黑。
- **根因**：所有内容区初始 `opacity: 0`，靠 JS 进场；fullPage 截图不触发滚动，元素永不进场。
- **修复**：先 dump section 地图拿 y 坐标，再真实 `scrollTo` → 等待 → 逐段截图。
- **教训**：**永远用"访客的方式"驱动页面**（真实滚动/点击）。脚本化截图是另一个产品。
- **附带**：整页长图即使不是黑的，也常常太长看不清 → 用 `slice-screenshot.py` 切段。

## #2 系统 python3 缺 Pillow + cwd 漂移

- **现象**：`python3 -c "import PIL"` 报 ModuleNotFoundError；换 venv 后相对路径又 FileNotFoundError。
- **修复**：用受管 venv `~/.workbuddy/binaries/python/envs/default/bin/python3`，
  脚本内一律**绝对路径**。
- **教训**：Bash 工具的 cwd 在多次调用之间可能重置，不要在脚本里依赖相对路径。

## #3 shell 代理导致本地 502 误判

- **现象**：`curl http://localhost:3100` 返回 502，但服务日志显示 Ready。
- **根因**：shell 有 HTTP 代理环境变量，curl 走了代理。
- **修复**：`curl --noproxy '*' http://127.0.0.1:3100` → 200。
- **教训**：**本地端口探测永远 `--noproxy '*'` + `127.0.0.1`**（`localhost` 有时也会走代理解析）。
  已固化进 `scripts/check-local.sh`。

## #4 node_modules 依赖损坏

- **现象**：`npm run lint` 直接 throw `Cannot find module 'prop-types/lib/has'`，随后 SIGTERM (exit 137)。
- **修复**：`rm -rf node_modules/prop-types node_modules/.package-lock.json && npm install`。
- **教训**：lint 报"模块解析"错误先查 node_modules 完整性，别先怀疑配置或代码。

## #5 后台服务用 nohup 起不来

- **现象**：`nohup npx next start &` 后 curl 000，日志文件为空。
- **根因**：`npx` 在后台非交互 shell 里的行为不稳定，且 nohup 的子进程被回收。
- **修复**：用受管后台任务直接执行
  `node node_modules/next/dist/bin/next start -p <port>`。
- **教训**：起本地服务用工具的后台任务机制，不要用 `nohup ... &`。

## #6 一次性 dump 两万字文案被静默截断

- **现象**：page-text.md 尾部直接从句子中间断掉，当时没察觉，Build 时凭印象补了一段假文案。
- **修复**：分段 dump（`.slice(0, 6)` 与 `.slice(6)` 各一次），落两个文件。
- **教训**：**截断处的丢失最难察觉**。长文本采集一律分段 + 核对字数。

## #7 资产 URL 没还原，下下来一堆转码图

- **现象**：直接 curl `_next/image?url=...` 拿到的图和页面里看到的不一样（尺寸/格式都不同）。
- **修复**：先跑 `unwrap-image-urls.py` 还原成 S3 原始地址再下载。
- **教训**：看到 `/_next/image` 或 `?objectUrl=` 就先还原，不要直接下载。

## #8 视频缺 muted/playsInline

- **现象**：克隆页的视频不自动播放。
- **根因**：浏览器拒绝自动播放**未静音**的视频；iOS Safari 缺 `playsInline` 会强制全屏。
- **修复**：四个属性必须齐全：`autoPlay muted loop playsInline` + `poster`。
- **教训**：把这条当 checklist 项，不要靠"我明明写了 autoPlay"来判断。

## #9 付费字体硬加载

- **现象**：源站用了 EuclidCircularA（付费），直接写进 font-family 后全部 fallback 到 system-ui，
  标题的几何感全丢。
- **修复**：找 metrics 接近的免费替代（Figtree / Manrope），再逐屏比对字宽与换行。
- **教训**：`fontsUsed` 拿到清单后**先判断付费与否**。中文则一律不加载 webfont。

## #10 已知不可消除的差异（声明模板）

克隆任务不要吹 pixel-perfect。交付时按这个模板列残留差异：

```markdown
## 残留差异

1. **persona 头像**：源站用动态头像服务，克隆用色环首字母替代。
   判定：接受 —— 不依赖外部服务，且视觉权重很低。
2. **焦点小组个别对白**：从视频帧读出，为合理近似。
   判定：接受 —— 已在 page-brief 标注。
3. **步骤 02–04 演示**：源站可能为视频/帧动画，克隆用 DOM 重建。
   判定：更优 —— 换来可编辑性与更小体积。
```

每一项三要素：**差异是什么 / 为什么没消除 / 判定与理由**。
