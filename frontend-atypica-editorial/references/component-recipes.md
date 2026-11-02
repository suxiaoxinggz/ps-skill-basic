# Component Recipes — JSX 级配方

> 参考实现全部在本仓库 `src/components/sites/atypica/`，可直接复制后改名复用。
> 本文件按 SKILL.md 第 3 节的幕序号组织。

## 目录

1. ScrollReveal（全局进场）
2. TypewriterPlaceholder（打字机）
3. Hero
4. TrustBar marquee
5. ProductDemo（滚动步进 + 假产品 UI）★核心
6. 反相纸面卡（评估 / 报告 / 引语通用）
7. 模型区轮播
8. FloatingPrompt（全页悬浮输入条）
9. 案例卡 / CTA / Footer
10. 客户端组件的边界

---

## 1. ScrollReveal（全局进场）

`src/components/sites/atypica/scroll-reveal.tsx`

任意元素声明 `data-reveal` 即自动进场，stagger 用 CSS 变量传：

```tsx
<div data-reveal style={{ ["--reveal-delay"]: "90ms" } as React.CSSProperties}>
```

要点：

- `threshold: 0.12` + `rootMargin: "0px 0px -48px 0px"`。
- 播完立刻 `unobserve`——播一次即停，不反复。
- reduced-motion 下直接给所有元素加 `.revealed`（或靠 CSS 媒体查询兜底）。

## 2. TypewriterPlaceholder（打字机占位）

`src/components/sites/atypica/typewriter.tsx`

- 3–4 条循环文案；**68ms/字进、24ms/字退，句尾停 1600ms**（接近真人节奏，别调更快）。
- 光标 `.at-caret`：1px 竖线 + `at-blink steps(1)`。
- ⚠️ React 19 lint `react-hooks/set-state-in-effect` 禁止在 effect 里同步 setState。
  reduced-motion 分支要写成 `setTimeout(() => setText(phrases[0]), 0)`。

## 3. Hero（电影幕）

`src/components/sites/atypica/hero.tsx`

```tsx
<section className="relative min-h-[calc(100vh-3.5rem)] overflow-hidden">
  <video
    src={...} poster={...} autoPlay muted loop playsInline
    className="absolute inset-0 h-full w-full object-cover"
  />
  {/* 双层渐晕：linear-gradient(180deg, bg/78% → bg/35% 40% → bg/88%) */}
  {/* 漂浮玻璃卡 ×3–4：absolute，hidden md:block */}
  <div className="rounded-xl border border-white/15 bg-black/45 p-4 backdrop-blur-md">
    <p className="text-[13px]">{title}</p>
    <p className="text-[12px] text-white/65">{body}</p>
    <span className="pill">{/* 绿点 + 10px 标签 */}</span>
  </div>
  {/* 左下内容流：badge pill → h1 → 说明段 → 输入条 */}
</section>
```

漂浮卡定位（1440 实测）：`left-[38%] top-[12%]`、`right-[4%] top-[28%]`、
`right-[12%] top-[44%]`、`left-[58%] top-[74%]`。**避开 h1 文字区**，小屏全隐藏。

## 4. TrustBar marquee

`src/components/sites/atypica/trust-bar.tsx`

列表 ×2 + `.at-marquee`（`width: max-content; animation: at-marquee 48s linear infinite`，
keyframes 平移 -50%）；logo `grayscale opacity-60`，hover 暂停。

## 5. ProductDemo ★

`src/components/sites/atypica/product-demo.tsx`

```tsx
<section>
  <div className="grid md:grid-cols-[1fr_1.4fr]">{/* eyebrow + h2 | 说明段 */}</div>
  <div ref={trackRef} className="relative md:h-[400vh]">
    <div className="md:sticky md:top-14 md:flex md:h-[calc(100vh-3.5rem)] md:gap-10">
      <div className="w-[300px]">{/* 大绿编号 + 步骤题 + 描述 + mt-auto mini 标签 */}</div>
      <MacFrame>{panels[activeStep]}</MacFrame>
    </div>
  </div>
</section>
```

active step 计算：

```ts
const rect = track.getBoundingClientRect();
const progress = clamp(-rect.top / (rect.height - window.innerHeight), 0, 1);
const active = Math.min(steps.length - 1, Math.floor(progress * steps.length));
```

MacFrame chrome：三点（`bg-white/20`）→ 品牌行（logo + 绿点 + 点数）→ 内容区。

四个面板配方：

- **Terminal 行**：`.at-exec`（mono 12px 绿）`› exec makeStudyPlan` + 右侧「查看过程」10px 白 40。
- **Persona 卡**：色环头像 `oklch(78% 0.12 hue)` + 首字母；姓名 11px + 类型 pill 9px 白 45 +
  两行评论 10px + 平台图标；网格 `grid-cols-2 gap-2`。
- **焦点小组**：同 Persona 卡 + 底部结论条 `bg-white/[0.04]` + 「查看原因」。
- **决策卡**：选项列表，选中项 `border-green/40 bg-green/10`；研究方案 bullet 卡；insight 引语用衬线。

通用底栏：`进度 3/7 · Panel 6` + `.at-thinking` 三点。
移动端降级：编号下加进度条，左右改上下堆叠。

## 6. 反相纸面卡

```tsx
<div className="relative rounded-lg bg-white p-1">
  <span className="at-tick left-1.5 top-1.5" />
  <span className="at-tick right-1.5 top-1.5" />
  <span className="at-tick left-1.5 bottom-1.5" />
  <span className="at-tick right-1.5 bottom-1.5" />
  <img className="aspect-[16/10] w-full rounded object-cover" />
</div>
```

`.at-tick`：6px 绿方块绝对定位四角——工程坐标点缀，评估卡 / 报告 / 论文全站复用。

报告 mock 透视：

```tsx
style={{ transform: "perspective(1200px) rotateX(4deg) rotate(2deg)" }}
```

配 `.at-lift` 深投影。学术论文用 ±2~3° 交替旋转错位排布。

## 7. 模型区轮播

`src/components/sites/atypica/model-section.tsx`

mono 页码 `01/04` + 白底内容卡（`min-h-[190px]` 防切换跳动）+ 圆点 / 箭头受控切换。
左列引语卡：serif 引号 `text-white/25 text-4xl` + 正文 18px/32px + 绿点署名。

## 8. FloatingPrompt

`src/components/sites/atypica/floating-prompt.tsx`

```tsx
<div className={`fixed bottom-6 left-1/2 z-30 w-[min(42rem,calc(100%-2.5rem))] -translate-x-1/2
  rounded-2xl border border-white/15 bg-black/70 backdrop-blur-md
  ${hidden ? "pointer-events-none opacity-0" : "opacity-100"}`}>
```

`#cta` 可见时淡出（IntersectionObserver threshold 0.2）。
⚠️ 不要做成 section 内 sticky（踩坑 #3）。

## 9. 案例卡 / CTA / Footer

- **案例卡**：`border-white/10 bg-white/[0.03] rounded-xl p-6` + `grayscale` 大 logo +
  右上「方向」pill + serif 引号 + `mt-auto` meta。
- **CTA**：`.at-glow` 径向辉光层 + 漂浮数据卡（同 Hero 配方，`rotate ±2~6°`）+ 居中输入条。
- **Footer**：`grid lg:grid-cols-[1.2fr_2fr]`；品牌列含 `● 系统运行中` 状态点；
  4 列链接 `text-[13px] text-white/55`。

## 10. 客户端组件的边界

只允许这四个是 client component：

1. `ScrollReveal` — 全局 IntersectionObserver
2. 打字机
3. 产品演示（滚动进度 → active step）
4. 轮播

其余全部 server component。这既是性能纪律，也防止逻辑被撒得到处都是——
一旦出现第五个 client component，先问"这个能不能靠 CSS 或 `[data-reveal]` 解决"。
