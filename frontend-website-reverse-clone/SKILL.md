---
name: frontend-website-reverse-clone
description: >-
  逆向克隆 / 复刻一个已存在的网页，产出可运行、可编辑的本地代码，而不是截图或 iframe。
  适用于：用户给一个 URL 要求"克隆这个网站""照着这个站做一个""复刻它的首页"
  "把这个落地页搬到我的 Next.js 项目里""1:1 还原某站"，或要求提取某个站的设计 token、
  section 结构、动效规则、资产清单用于复刻。也适用于克隆后逐屏比对找视觉偏差。
  核心是六阶段流程（Map → Observe → Extract → Build → Compare → QA）和一套能直接跑的
  采集脚本（section 地图、computed style、全文案 dump、资产 URL 还原、长图切片、批量下载）。
  即使用户只说"帮我看看这个站怎么做的"，只要最终目标是产出代码，就应该使用本 skill ——
  凭印象照着截图写代码一定会漏掉 section、资产和滚动行为。
compatibility: >-
  需要一个能驱动的浏览器（MCP playwright 工具，或 npm i -D playwright）。
  落地栈以 Next.js App Router + Tailwind v4 为例；流程本身与框架无关。
---

# 逆向克隆一个网站

## 1. 先理解为什么，再动手

克隆网站的目标**不是像素级截图**，而是产出**可运行、可编辑的代码**。
截图、iframe、下载下来的生产包都只是参考资料，不是实现。

这条边界决定了整个流程：你要采集的是**规则**（这个站用什么字号、什么间距、
什么断点行为、什么动效驱动），而不是**一张图**。所以 Observe 阶段要"像访客一样
驱动页面"——真实滚动、真实点击——而不是脚本化地把 DOM 扒下来。

第二个原则：**先有证据，再写代码**。每次写组件前，手上应该有：该 section 的截图、
它的文案原文、它的 computed style、它用到的资产。缺任何一样就去补，不要靠猜。

## 2. 六阶段流程

### 阶段 1 — Map：搞清楚要克隆什么

- 读项目约定（AGENTS.md / README），确认落地目录。本仓库：`src/app/`、
  `src/components/sites/<site>/`、`public/sites/<site>/`、`docs/research/<site>/`。
- 打开源站，确认路由清单。多页面要保留源站 pathname；
  query/fragment 变化通常代表同一路由的不同状态，要复现状态。
- 记录 **源站 URL → 本地路由 → 归属文件** 的映射表。不同源站用不同 app，
  或加路由前缀 + 作用域隔离字体与样式。

### 阶段 2 — Observe：像访客一样驱动页面

⚠️ **最关键的一条**：整页截图（`fullPage: true`）对滚动触发型站点**基本全黑**。
因为内容区初始 `opacity: 0`，靠 JS 进场；不滚动就永远不进场。

正确顺序：

1. 先 dump **section 地图**（`querySelectorAll('section')` + top / height / innerText 摘要）。
2. 再**真实滚动**逐段截图：按 section 的 y 坐标 `scrollTo` → 等待 → 截图。
3. 同时看桌面（1440）与移动（375）两个宽度。
4. 操作交互：菜单、tab、accordion、轮播、hover、主链接。
   **区分滚动驱动 vs 点击驱动 vs 时间驱动**——用点击模仿一个滚动驱动的 section
   是另一个产品，用户一上手就会发现。

截图命名带视口 + 滚动位置 + 交互状态，例如
`desktop-1440-y2400.png`、`mobile-375-menu-open.png`。

采集用的 JS 片段（section 地图 / computed style / 全文案 / 资产 URL）
全是 paste 现成的，见 `references/capture-recipes.md`。

### 阶段 3 — Extract：把规则抽出来

三件事，缺一不可：

1. **Computed styles**：h1 / h2 / body / 按钮 / CSS 变量 / 全站字体清单。
2. **全文案**：每个 section 的 `innerText` dump 成 md，后面逐字比对。
3. **资产 URL**：`img[src]`、`video[src]`、`background-image` 里的 `url()`。

⚠️ Next.js 站的 `img.src` 常常是 `/_next/image?url=...` 代理包装，
直接下载会拿到错误格式。先还原成原始 URL 再下载：

```bash
python3 <skill>/scripts/unwrap-image-urls.py asset-urls.json > originals.txt
```

输出一份 `docs/research/<site>/page-brief.md`：section 地图 + tokens + 字体 +
字号刻度 + 资产清单 + 动效观察。这份文档是后面所有 builder 的唯一事实来源。

### 阶段 4 — Build：完整的第一遍

顺序固定，别跳：

1. 字体 + 页面宽度 + 颜色 token + 全局件（sticky 导航、reveal observer、悬浮条）。
2. 共享组件（带齐所有状态：hover / focus / 断点）。
3. 逐 section 施工，每个 section 都用**真实文案 + 源站原资产**。
   同名的替代字体或图标集有不同的 metrics，会立刻露馅。
4. 交互：保留真实外链目标；范围内的路由改写为本地路由；
   看得见的控件必须真的能按它承诺的那样工作。

先跑一次集成检查再继续，别攒到最后。

### 阶段 5 — Compare：同视口、同滚动位、同状态

源站与本地**必须**在同一视口、同一滚动位置、同一交互状态下并排看。
等字体、媒体、进场动画都稳定下来再截图。

修复优先级（从大到小）：几何结构 → 缺失的 section/图层 → 字体与换行 →
资产裁切 → 间距 → 动效。

⚠️ 只修"可见差异"，凭印象改会引入新偏差。

### 阶段 6 — QA：跑项目的生产检查

构建 + 类型检查 + lint 必须全绿；检查横向溢出、控制台报错、缺失资产、
移动端菜单与轮播边界。**主动声明残留差异**，不要说 unchecked 的结果是 pixel-perfect。

## 3. 采集工具箱

| 脚本 | 干什么 |
|---|---|
| `scripts/unwrap-image-urls.py` | 把 `_next/image` / `objectUrl` 包装的 URL 还原成原始地址并去重 |
| `scripts/fetch-assets.sh` | 批量下载资产，带重试、超时、content-type 校验、失败清单 |
| `scripts/slice-screenshot.py` | 把超长整页截图切成 N 段便于逐段看（配合真实滚动截图使用） |
| `scripts/check-local.sh` | 本地服务健康检查（`--noproxy` + 127.0.0.1，避开代理误判） |

```bash
python3 <skill>/scripts/unwrap-image-urls.py docs/research/x/asset-urls.json > originals.txt
bash <skill>/scripts/fetch-assets.sh originals.txt public/sites/x/assets
python3 <skill>/scripts/slice-screenshot.py full.png --bands 10 --width 720
bash <skill>/scripts/check-local.sh 3100
```

## 4. 常见失败模式

- **靠整页截图写代码** → 一半内容是黑的，漏掉整个 section。（见 error-log #1）
- **把滚动驱动的 sticky 场景做成点击切换** → 手感完全不对。
- **用同名替代字体/图标** → metrics 不同，一眼假。
- **资产用占位图或重新生成的近似图** → 失去克隆的意义。
- **没验证 content-type** → `.png` URL 可能返回 AVIF，浏览器能显示但你的管线不能。
- **本地服务探测走代理** → 502 误判成服务没起来。（见 error-log #7）
- **交付时不声明残留差异** → 用户自己发现，信任归零。

## 5. References

| 文件 | 内容 | 什么时候读 |
|---|---|---|
| `references/capture-recipes.md` | 现成的浏览器采集 JS（section 地图 / computed style / 文案 dump / 资产 URL / 视频清单） | 阶段 2–3 |
| `references/asset-pipeline.md` | 资产还原、下载、格式校验、目录约定的完整做法 | 阶段 3 |
| `references/compare-checklist.md` | 逐屏比对的检查项与偏差分类法 | 阶段 5 |
| `references/error-log.md` | 采集与环境踩坑全集 | **开工前读一遍** |
| `references/stack-notes-next.md` | Next.js App Router + Tailwind v4 落地时的具体注意点 | 阶段 4 |

交叉：如果克隆目标是一个**暗色 editorial / 电影感 AI SaaS 首页**，
落地阶段配合 `atypica-editorial` skill 使用——它提供设计语言，本 skill 提供采集与工程流程。
