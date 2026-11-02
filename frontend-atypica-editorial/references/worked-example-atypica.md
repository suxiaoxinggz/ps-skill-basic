# Worked Example — atypica.ai 首页拆解

> 这套语言的样本来源。读它是为了看**具象的样子**，不是为了照抄——
> 你的项目有自己的文案、资产和产品，规则要套，内容要换。

## 页面总览

- URL：https://atypica.ai/
- Title：面对任何商业决策，预演人们会如何反应 | atypica.AI
- 页面总高：~10,007px，10 个语义 `<section>`
- 框架：Next.js（`/_next/image` 资产管线）+ Tailwind + oklch tokens
- 采集时间：2026-10-22，Playwright Chromium，1440×900

## Section 地图（y 坐标为页面绝对位置）

| # | 幕 | y 范围 | 内容 |
|---|---|---|---|
| 1 | Hero `home-v2-hero-fullscreen` | 0–860 | 全屏背景视频 + 深色渐晕；左下 badge「商业 AI · 人类模拟」、h1 两行、说明段、底部输入条；右侧漂浮玻璃卡（Market Fit / Segmentation / Audience Simulation） |
| 2 | TrustBar | 900–1136 | eyebrow「THE AI BUSINESS RESEARCH PLATFORM TRUSTED BY LEADING BRANDS WORLDWIDE」+ 18 个灰度 logo（P&G / Bosch / LVMH / Volvo / Bain / 美团 …） |
| 3 | 产品演示 | 1216–4816（h=3600） | 左 sticky：巨大绿编号 01→04 + 步骤题 + 描述 + mini 标签；右 macOS 窗口框（三点 + atypica.AI + 点数 1,240）|
| 4 | 评估 | 4896–5536 | 三列白底图表卡（四角绿色十字标）+ 题目 + 说明 |
| 5 | 从模拟到报告 | 5536–6228 | 左文案 + 绿勾清单 + 「查看一份真实报告 →」；右倾斜白纸报告 mock |
| 6 | 模型 | 6228–7153 | 网格线背景；h2 内嵌衬线「主观世界模型」；白色引语卡 + 「四层证据」轮播 |
| 7 | 实践中的模拟 | 7153–7837 | 三张暗卡（BOSCH / LVMH / BAIN & COMPANY）+「方向」pill + 引语 + meta |
| 8 | 研究 | 7837–8974 | 「企业实践研究」+ 左学术验证倾斜白论文 + 右大学 logo 墙 + 概念测试轮播（进度条 28%）|
| 9 | CTA | 8974–9535 | 中央暗玻璃大输入条 + 白按钮；四周倾斜漂浮数据卡 + 暗绿径向辉光 |
| 10 | Footer | 9615–9959 | 品牌列（为「主观世界」建模 / © 2026 BMRLab / 社交 / ● 系统运行中）+ 四列链接 |

## 产品演示的四个步骤（第 3 幕）

| 编号 | 标题 | 演示形式 |
|---|---|---|
| 01 | 设计你的研究 | 循环 mp4（`home-v2-swm-product-demo`） |
| 02 | 构建 Persona 人群 | 终端日志（`exec.*` 绿色 mono）+ persona 卡片网格（姓名 / 类型 pill / 平台图标 / 评论 / `进度 3/7 · Panel 6`）|
| 03 | 预演人们的反应 | 焦点小组聊天流（6 人发言 + 「查看原因」）|
| 04 | 越用越懂研究 | 决策卡（选项单选 + 研究方案 bullet + insight 引语）|

## 全局细节

- 顶部公告条：深灰条、居中文案、下划线链接「了解更多」、右侧 ×。
- 导航：sticky、暗底（滚动后带 blur），logo `atypica.`**`AI`**（AI 为绿色），
  菜单 技术/产品/解决方案 带下拉 chevron、价格；右侧白底黑字按钮「开始免费试用」+ 汉堡。
- 绿色十字标记 `.at-tick` 散布各 section——工程坐标点缀。
- mini 标签行用中点连接：`问题 · 对象 · 方法`、`PERSONA · 人群 · 背景`。
- 全局悬浮输入条：打字机循环 + 白色按钮「免费开始研究 >」。

## 实测 Tokens（computed style）

```
--background: oklch(21% .006 285.885)
--foreground: oklch(98.5% 0 0)
--primary:    oklch(87% .29 142.57)
--card:       oklch(23.5% 0 0)
--accent/--muted: oklch(26.9% 0 0)
--border:     oklch(100% 0 0 / .1)
--radius:     .5rem
```

fontsUsed 实测：`system-ui / EuclidCircularA / Instrument Serif / IBMPlexMono /
SFMono-Regular / Times New Roman`。中文全部走系统回退。

## 设计哲学原文要点

atypica 设计团队自述《The Less AI, The More AI》：

- 拒绝"AI 就该有霓虹渐变和粒子"的廉价未来感；
- 用电影摄影、建筑摄影、编辑设计的专业语言传达"对人的深刻理解"；
- 冲击力来自戏剧化明暗对比、强几何构图、电影感光位、建筑尺度，而不是特效叠加；
- 人物出现时是主体而不是比例尺。

## 资产清单（已下载到 `public/sites/atypica/assets/`）

- `hero-bg-video.mp4` / `hero-bg-video-3.mp4` / `hero-poster.jpg`
- `product-demo.mp4` / `product-demo-poster.jpg`
- `logos/*.webp` ×14 + `kimberly-clark.svg`
- `eval/*.webp` ×3（三张基准图表）
- `report/*.webp` ×2（报告纸面）
- `concept/*.jpg` ×3、`uni-partners.png`
- 下载脚本：`scripts/download-atypica-assets.sh`
- 源站资产根：`https://bmrlab-prod.s3.us-east-1.amazonaws.com/atypica/public/`

## 残留差异（诚实声明）

1. persona 头像：源站用动态头像服务，克隆用色环首字母替代。
2. 焦点小组个别对白从视频帧读出，为合理近似。
3. 步骤 02–04 源站可能为视频/帧动画，克隆用 DOM 重建 —— 换来可编辑性与更小体积。
