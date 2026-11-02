# Design Tokens — 完整规格

> 数值来自 atypica.ai 首页的 computed style 实测，已泛化。**改任何一项都要同步改全套**，
> 尤其是 `--at-bg` 的 chroma 和 accent——只改一半会得到"哪里不对但说不上来"的页面。

## 目录

1. 颜色
2. 字体
3. 字号刻度
4. 间距 / 尺寸 / 圆角
5. 投影与辉光
6. 常见改色错误

---

## 1. 颜色

| Token | 值 | 用途 | 备注 |
|---|---|---|---|
| `--at-bg` | `oklch(21% 0.006 285.885)` | 页面底色 | 近 `#1c1c1f`。chroma 0.006 + hue 285.885 = 极微弱冷紫。**别用纯黑** |
| `--at-fg` | `oklch(98.5% 0 0)` | 正文 | 近白但不刺眼 |
| `--at-green` | `oklch(87% 0.29 142.57)` | 唯一 accent | 视感 ≈ `#86ff9e` |
| `--at-card` | `oklch(23.5% 0 0)` | 卡片面 | 比底亮 2.5 个百分点，够分离又不跳 |
| `--at-muted` | `oklch(26.9% 0 0)` | 次级面 / hover 态 | |
| `--at-border` | `oklch(100% 0 0 / 10%)` | 发丝线 | 白 10%。全站唯一的描边语言 |
| 次级文本 | `oklch(100% 0 0 / 60~75%)` | 说明段、meta | 60% = eyebrow，75% = 正文 |
| 玻璃面 | `rgba(0,0,0,.45~.55)` + `backdrop-blur-md` | Hero/CTA 漂浮卡、输入条 | |
| CTA 辉光 | `radial-gradient(60% 55% at 50% 62%, oklch(45% 0.14 150 / 34%), transparent 70%)` | 只在 CTA 幕 | 全站唯一一次"发光" |
| 网格背景 | `linear-gradient(白/3% 1px, transparent 1px) ×2`，`size 56px` | 模型幕 | |
| 纸面 | `#ffffff` + `0 40px 120px -40px rgba(0,0,0,.9)` | 图表卡 / 引语卡 / 报告 mock | 反相锚点 |
| 窗口框 | 框 `oklch(17% 0 0)`、内容区 `oklch(19% 0 0)` | macOS demo 框 | 比页面底更暗，做出"屏幕中的屏幕" |

### accent 的准入清单

accent 只允许出现在这些位置，除此之外一律中性色：

- logo 的后缀字符（atypica.**AI**）
- 步骤的大编号（01 / 02 / 03 / 04）
- 当前活动态（选中项边框 `border-green/40` + `bg-green/10`）
- 进度点、状态点（`● 系统运行中`）
- 工程角标十字 `.at-tick`
- terminal 日志文本 `.at-exec`
- 清单的勾选图标

**反面**：accent 铺底、accent 按钮大面积、accent 标题、accent 图标森林。

## 2. 字体

```css
--at-display: var(--font-display), system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
--at-serif:   var(--font-serif-accent), "Times New Roman", serif;
--at-mono:    var(--font-mono-alt), SFMono-Regular, monospace;
```

| 角色 | 源站字体 | 免费替代 | 用途 |
|---|---|---|---|
| Display | EuclidCircularA | **Figtree**（Manrope / Inter Tight 亦可） | h1 / h2 / 大编号 / logo |
| 正文 | system-ui | system-ui + 中文回退 | 段落、UI 文案 |
| 衬线强调 | Instrument Serif | Instrument Serif（免费） | 标题内嵌一两个词的引语式强调 |
| Mono | IBMPlexMono | **IBM Plex Mono** | terminal 行、eyebrow、页码元数据 |

**中文一律走系统回退**（PingFang SC / Microsoft YaHei / Noto Sans SC）。
加载中文 webfont 是首屏性能自杀，且系统字体在这套暗色版式里观感更好。

Next.js 接入（`app/layout.tsx`）：

```tsx
import { Figtree, Instrument_Serif, IBM_Plex_Mono } from "next/font/google";

const display = Figtree({ subsets: ["latin"], variable: "--font-display" });
const serif   = Instrument_Serif({ subsets: ["latin"], weight: "400", variable: "--font-serif-accent" });
const mono    = IBM_Plex_Mono({ subsets: ["latin"], weight: "400", variable: "--font-mono-alt" });

// <html className={`${display.variable} ${serif.variable} ${mono.variable}`}>
```

## 3. 字号刻度

| 元素 | 桌面 | 移动 | 细节 |
|---|---|---|---|
| h1 | 60px / 500 / lh 1.08 / ls +1.5px | `clamp(34px, 4.2vw, 60px)` | 中文标题 ls 用 0.025em |
| h2 | 36px / 500 / lh 1.18 / ls -0.9px | 30px / ls -0.75px | 负字距是"高级感"的 cheapest trick |
| h3 步骤题 | 24px / 500 / ls -0.6px | 20px | |
| h3 卡片题 | 16–20px / 500 | — | |
| eyebrow | 12px / ls 0.08em / 白 60% | 同 | |
| 大编号 | 60px / 500 / accent | 同 | |
| 正文段 | 15px / lh 28px / 白 75% | 14px | |
| mini 标签 | 10px / uppercase / ls 0.14em / 白 40% | — | 用中点 `·` 分隔 |
| mono 元数据 | 12px | — | terminal 行、`01/04` 页码 |

## 4. 间距 / 尺寸 / 圆角

- 容器 `max-w-[1400px] px-5`；导航高 **56px（3.5rem）**——sticky 偏移全部按这个值算。
- Section 垂直节奏：常规 `py-16 md:py-20`；重段（产品、模型）`py-20 md:py-28`。
- 产品区滚动轨道：`md:h-[400vh]`（4 步 × 100vh）+ sticky `top-14 h-[calc(100vh-3.5rem)]`。
- 圆角：卡 `rounded-xl`（12px）→ 按钮 / 输入 `rounded-lg`（8px）；基准 `--at-radius: .5rem`。
- Hero 漂浮卡宽 200–220px；demo 框内容区高 `h-[480px] md:h-[520px]`。
- 窗口框内边距 `p-4`；纸面卡内边距 `p-1`（图紧贴，四角标在 padding 里）。

## 5. 投影与辉光

投影只给**离页**元素——白纸卡和 macOS 窗口框：

```
0 40px 120px -40px rgba(0,0,0,.9)     /* 离页（纸面卡 / 报告 mock / 窗口框） */
0 40px 100px -40px rgba(0,0,0,.9)     /* 稍近的纸面卡 */
```

暗卡一律**不加**阴影，只用 `border-white/10` + 必要时 `bg-white/[0.03]` 区分层次。
在暗底上加阴影只会让边缘变脏。

## 6. 常见改色错误

| 想做 | 别这样 | 应该 |
|---|---|---|
| 换个品牌色 | 把 `--at-green` 换成蓝色，同时留着绿色角标 | 全量替换 accent，全站**只有一个** |
| 底色更暗 | `--at-bg: #000` | 保留 chroma ≤0.01 的冷偏移 |
| 让卡片更明显 | 加阴影 | 改 `--at-card` 亮度或加 `border-white/10` |
| 强调一句话 | 整句变绿 | 内嵌衬线强调（白色），或只强调一个词 |
| CTA 更抓眼 | 更大更亮更绿 | 辉光已经是上限，再往上就俗了 |
