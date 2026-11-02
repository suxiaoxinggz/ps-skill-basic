# Error Log — 实操踩坑记录

> 来源：atypica.ai 首页 1:1 克隆实操（2026-10-22），以及后续复用中的新增条目。
> **开工前读一遍**，能省掉一半返工。采集/环境类的坑见 `website-reverse-clone` skill 的同名文件。

## 目录

- #1 悬浮输入条做成了 section 内 sticky
- #2 React lint：effect 内同步 setState
- #3 JSX 字符串内裸换行 = 语法错误
- #4 视觉偏差四连（Compare 阶段逐条修）
- #5 衬线强调词被做成 accent 色
- #6 案例 logo 忘了灰度
- #7 client component 溢出
- #8 滚动轨道高度与步骤数不匹配
- #9 已知不可消除的差异（诚实声明）

---

## #1 悬浮输入条做成了 section 内 sticky

- **现象**：滚过产品区后，「免费开始研究」条顶在评估区内容上，遮住标题。
- **根因**：源站的输入条是**全页 `fixed` bottom 居中**，我误判为产品区局部 sticky。
- **修复**：抽成页面级 `FloatingPrompt` 客户端组件
  （`fixed bottom-6 left-1/2 -translate-x-1/2`），IntersectionObserver 监听 `#cta`，可见时淡出。
- **教训**：**同一条 UI 出现在多个 section 的截图里 ⇒ 先怀疑它是 fixed 全局件，不是局部组件。**

## #2 React lint：effect 内同步 setState

- **现象**：`react-hooks/set-state-in-effect` error——打字机 reduced-motion 分支在 effect 里
  直接 `setText(phrases[0])`。
- **修复**：`setTimeout(() => setText(...), 0)` 包裹（异步回调合法）。
- **教训**：React 19 新 lint 对级联渲染很严格。"读一次媒体查询再设初值"这类模式一律走异步。

## #3 JSX 字符串内裸换行 = 语法错误

- **现象**：长中文文案字符串里直接回车，typecheck 报错。
- **修复**：合并为单行，或用 `\n` + `whitespace-pre-line`。
- **教训**：中文长段落不要靠编辑器自动换行，写进 JSX 前先压平。

## #4 视觉偏差四连（Compare 阶段逐条修）

1. 悬浮条 fixed 化（见 #1）。
2. Hero 漂浮卡压住 h1 尾部 → 上移至 `top-[12%]`、右移 `left-[38%]`。
3. 案例 logo 彩色（Bosch 红）→ 源站整体 muted → `grayscale opacity-80`。
4. 模型区衬线强调词颜色（见 #5）。

- **教训**：Compare 阶段要**同视口、同滚动位置**逐屏比对，只修"可见差异"。
  凭印象改会引入新偏差。

## #5 衬线强调词被做成 accent 色

- **现象**：初版把「主观世界模型」写成绿色斜体衬线。
- **根因**：想当然地认为"强调 = accent 色"。
- **修复**：源站是**白色**衬线（中文回退后呈宋体感）→ 去绿、去斜体。
- **教训**：accent 有准入清单（见 design-tokens.md），"强调"不在其中。
  强调靠**字体切换**而不是颜色。

## #6 案例 logo 忘了灰度

同一条根因：暗色版式里任何彩色元素都会跳出来抢戏。logo 墙、案例卡、合作伙伴墙
一律 `grayscale`，hover 才恢复。

## #7 client component 溢出

- **现象**：为了一个小交互（比如 hover 展开）给整个 section 加 `"use client"`。
- **后果**：JS 体积膨胀、hydration 成本上升，且逻辑开始到处蔓延。
- **修复**：把交互下沉到最小叶子组件；能用 CSS `:hover` / `[data-reveal]` 解决的就别用 JS。
- **纪律**：client component ≤ 4 个。出现第 5 个先问能不能靠 CSS 解决。

## #8 滚动轨道高度与步骤数不匹配

- **现象**：4 个步骤用了 `300vh`，最后一步永远走不到（或最后一步停留时间极短）。
- **修复**：轨道高度 = `步骤数 × 100vh`，且 `active` 要 `Math.min(n-1, ...)` clamp。
- **教训**：改步骤数时记得同步改轨道高度——这两个数字是绑定的。

## #9 已知不可消除的差异（诚实声明）

克隆类任务不要吹 pixel-perfect。这次残留的三处差异与判定：

- 源站 persona 头像来自动态头像服务 → 克隆用 `oklch(78% 0.12 hue)` 色环 + 首字母替代。
  若追求像素级，可截图后转静态资源；判定当前 trade-off 更优（不依赖外部服务）。
- 焦点小组个别对白从视频帧读出，是合理近似（已标注在研究简报）。
- 步骤 02–04 的演示在源站可能是视频/帧动画，本次用 DOM 重建 —— 换来可编辑性与更小体积。

**交付时主动声明残留差异**，比被用户发现好得多。
