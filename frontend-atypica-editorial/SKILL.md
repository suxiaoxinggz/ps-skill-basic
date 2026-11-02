---
name: frontend-atypica-editorial
description: >-
  用「高级杂志式 SaaS 设计 × 电影感视觉叙事 × 交互式产品演示」这套首页设计语言，构建或评审
  AI / SaaS 产品的落地页。当你需要暗色 editorial 版式、电影感的滚动叙事、把假产品 UI
  （agent 工作流 / 终端日志 / 焦点小组 / 决策卡）当成证据来展示、用反相白纸卡制造对比锚点、
  或需要一套克制而 technical 的动效规范时使用。适用场景包括但不限于：用户说"atypica 风格"
  "editorial SaaS""杂志式 / 社论式 SaaS 首页""电影感落地页""带产品演示的首页""暗色高级感
  landing page""像 Linear / Vercel / atypica 那种质感的官网"，或要求克隆 / 复刻某个 AI 产品官网、
  评审一个首页够不够"高级"、把一个通用 SaaS 模板改造成有叙事张力的版本。
  即使用户没有说出这些词，只要任务本质是"做一个看起来专业、可信、有电影感的 AI / SaaS 首页"，
  就应该使用本 skill —— 通用的居中 hero + 圆角卡片阵列 + 软阴影是不合格的默认输出。
compatibility: >-
  最佳载体是 Next.js App Router + Tailwind v4（oklch token 直接写 CSS 变量）。
  核心规则（配色纪律、叙事编排、动效克制、反相纸面）与框架无关，任何 React / Vue / 纯 HTML 均可套用。
---

# 高级杂志式 SaaS × 电影感视觉叙事 × 产品即证据

这套语言源自对 atypica.ai 首页的一次完整 1:1 克隆实操，并综合了 MengTo/Skills 的
editorial-tech、cinematic-scroll-storytelling、product-proof-saas，以及 anthropic 的
frontend-design。下面所有规则都已从 atypica 这一个样本里抽出来泛化——**atypica 只是 worked
example，不是这套语言的边界**。

## 1. 先理解为什么，再动手

这套语言的原点是一句反直觉的判断：**"越少 AI 表象，越多 AI 实质"**。

当一个产品卖的是"智能"，最廉价的表达方式就是霓虹渐变、3D 渲染、粒子特效、漂浮的几何体——
它们只证明你会用特效库。真正让人相信一个产品聪明的方式，是让它看起来像一份严肃的
专业出版物：编辑设计的排版纪律、电影摄影的光影、工程图纸般的精确点缀。**可信度来自克制。**

配套的一条：**产品演示即证据（product-proof）**。界面本身要能证明产品会做什么，而不是装饰。
让真实工作流（输入 → 处理 → 产出）在页面上可见；宁可标注 "Sample workflow"，也不要做一个
假装在实时生成、却解释不了自己状态变化的 marketing mockup。

### 三条不可协商的视觉纪律

**① Color as Drama, Not Decoration**
色彩是戏剧手段，不是涂料。70% 中性（黑/白/灰）+ 30% **单一** accent。
accent 只出现在：logo 后缀、超大编号、活动态、进度点、工程角标、terminal 文本。
禁止用 accent 大面积铺底，禁止第二个 accent，禁止彩虹渐变，禁止色相差 <30° 的近似色搭配。
整套页面里"发光"只允许出现一次——最终 CTA 的径向辉光。

**② Type as Voice**
四种字体角色分工明确，不要混用：
Display（几何无衬线，h1/h2/编号/logo）、正文（system-ui + 本地中文回退）、
衬线强调（标题里内嵌一到两个词的引语式强调）、Mono（terminal 行、eyebrow、元数据页码）。
中文不加载 web 字体，走系统回退——中文 webfont 是首屏杀手。

**③ Motion as Proof**
动效的目的是"证明系统在运行"和"引导视线"，不是取悦。
所以：进场 reveal 播一次就停（never twitchy）、打字机速度接近真人、
agent 思考中的呼吸点要和真实等待时长同量级。一切动效必须有 `prefers-reduced-motion` 静态回退。

## 2. Design Tokens（精简版，完整规格见 references/design-tokens.md）

```css
:root {
  --at-bg:     oklch(21% 0.006 285.885);  /* 暗中性底：hue 285.885 给了极微弱冷紫，别用纯黑 */
  --at-fg:     oklch(98.5% 0 0);
  --at-green:  oklch(87% 0.29 142.57);    /* 唯一 accent */
  --at-card:   oklch(23.5% 0 0);
  --at-muted:  oklch(26.9% 0 0);
  --at-border: oklch(100% 0 0 / 10%);     /* 白 10% 发丝线 */
  --at-radius: 0.5rem;
}
```

三个最容易做错的点：

- **底色带 hue**。纯 `#000` 或纯灰会立刻掉回"通用模板"。一个几乎察觉不到的冷色偏移
  （chroma 0.006）就是"有设计"和"没设计"的分界。
- **反相纸面**。在暗页上放纯白卡片（图表、报告、引语、论文），是整套页面最强的对比锚点。
  白卡配大扩散深投影 `0 40px 120px -40px rgba(0,0,0,.9)`；暗卡**不用**阴影，只用 `border-white/10`。
- **投影只给"离页"元素**。暗卡堆阴影会变成泥。

字号刻度（桌面 / 移动）：h1 `clamp(34px,4.2vw,60px)` / 500 / lh 1.08 / ls +1.5px；
h2 36px→30px / ls -0.9px；eyebrow 12px / ls .08em / 白 60%；正文 15px / lh 28px / 白 75%；
mono 元数据 12px。完整刻度表见 references/design-tokens.md。

## 3. 首页叙事编排（10 幕）

一个 editorial-cinematic 首页不是"功能模块堆叠"，是一条**有起承转合的片子**。
按下面顺序组装，每一幕承担一个明确的叙事职责：

| # | 幕 | 职责 | 关键手法 |
|---|---|---|---|
| 1 | 公告条 | 建立"正在运营中"的真实感 | 深灰全宽条 + 下划线链接 + 可关闭 × |
| 2 | 导航 | 收敛注意力 | sticky + backdrop-blur，logo 后缀用 accent，右侧实底 CTA |
| 3 | Hero | 定调：这是电影，不是模板 | **全屏 muted 循环视频**（实拍/摄影感）+ 双层渐晕 + 左下内容流 + 四周漂浮玻璃证明卡 |
| 4 | 信任条 | 社会证明，一笔带过 | uppercase letterspaced eyebrow + 无限 marquee 灰度 logo |
| 5 | **产品演示（全页最重）** | 证明产品会做什么 | 左 sticky 步骤栏（巨大 accent 编号 01→04）× 右窗口框假产品 UI，滚动驱动切换 |
| 6 | 评估 / 指标 | 用数据接住演示 | 三列**反相白纸卡** + 四角工程十字标 |
| 7 | 报告 / 产出 | 让用户看到"我拿到的是什么" | 透视倾斜的报告 mock（`perspective + rotateX(4deg) rotate(2deg)`） |
| 8 | 模型 / 方法论 | 回答"凭什么可信" | 工程网格背景 + h2 内嵌衬线强调词 + 引语卡 + 轮播 |
| 9 | 客户案例 | 落到具体的人与公司 | 暗卡 + 灰度大 logo + serif 引号 |
| 10 | CTA | 唯一一次情绪上扬 | 径向辉光 + 倾斜漂浮数据卡 + 居中输入条 |

外加一个**全局悬浮件**：底部居中 fixed 玻璃输入条（打字机循环真实问题 + CTA 按钮），
滚到 CTA 区时淡出——因为 CTA 自己有 in-flow 的输入条，同时出现两个会打架。

完整分幕脚本（含每幕的文案结构、尺寸、降级策略）见 references/narrative-acts.md。

## 4. 动效规范

- **进场 reveal**：`opacity 0→1 + translateY(28px→0)`，`cubic-bezier(.16,1,.3,1)` 0.9s，
  卡片组 90ms stagger；IntersectionObserver（threshold .12，rootMargin 底部 -48px）触发，
  `unobserve` 播一次即停。
- **打字机**：68ms/字进、24ms/字退，句尾停 1.6s。reduced-motion 时静态显示首句。
- **marquee**：48s linear infinite，列表 ×2 平移 -50%，hover 暂停。
- **思考点**：三点 1.2s 交错呼吸。
- **hover 只做三件事**：logo 透明度、按钮 opacity / scale(1.05)、箭头位移。
  **禁止** bounce、spring、wobble——任何"活泼"的缓动都会立刻把高级感打回玩具感。

完整规范与代码片段见 references/motion-spec.md。

## 5. 落地流程

**第 0 步：铺 token。** 跑一次脚手架，把 token 与工具类写进项目，别手抄：

```bash
node <skill>/scripts/init-design-tokens.mjs --target ./src/app
```

它会写入 `editorial-tokens.css`（全部变量 + `.at-tick` / `.at-marquee` / `.at-caret` /
`.at-exec` / `.at-thinking` / `[data-reveal]` 等工具类）并打印下一步（字体接入与 import 位置）。

**第 1–5 步：按幕施工。** 每一幕的 JSX 级配方（结构、class、踩坑点）在
references/component-recipes.md，按第 3 节的幕序号对号入座。

施工顺序建议：先 tokens + 字体 + 全局件（ScrollReveal / 悬浮输入条）→ 再 Hero 定调 →
再做第 5 幕产品演示（最耗时，先做能尽早暴露滚动问题）→ 补齐其余 → 最后 CTA 与 Footer。

**客户端组件只应该有四个**：`ScrollReveal`（全局 observer）、打字机、产品演示（滚动进度 →
active step）、轮播。其余全部 server component——这一条既是性能纪律，也是防止你把逻辑撒得到处都是。

**第 6 步：交付前跑检查清单。** references/qa-checklist.md。最低要求：lint + typecheck + build
全绿、无横向溢出、reduced-motion 下页面依然完整可读。

## 6. 常见失败模式

看到下面任何一条，说明已经偏离这套语言：

- 通用居中式 SaaS hero + 等宽圆角卡片阵列 + 软灰阴影（三个一起来 = 模板味）。
- 霓虹 / 青绿 HUD 过载、AI 粒子、无限漂浮玻璃卡（漂浮卡只允许出现在 Hero 与 CTA 两幕）。
- accent 到处撒、用彩色背景块、出现第二个 accent 色。
- 假装的"实时生成"演示——无法解释自身状态变化的 UI 会摧毁信任而不是建立信任。
- 滚动动效没有 reduced-motion 回退。
- 把悬浮输入条做成 section 内 sticky（滚出该 section 后会顶在内容上；真实踩过的坑，见 references/error-log.md #3）。

## 7. References

| 文件 | 内容 | 什么时候读 |
|---|---|---|
| `references/design-tokens.md` | 完整色板、字体栈、字号刻度、间距/圆角/投影规格 | 落地第 0 步之后 |
| `references/narrative-acts.md` | 10 幕分镜脚本：每幕职责、文案结构、尺寸、响应式降级 | 编排页面结构时 |
| `references/component-recipes.md` | 全部组件的 JSX 级配方（含参考实现文件指针） | 写具体组件时 |
| `references/motion-spec.md` | 缓动曲线、时长、observer 参数、reduced-motion 处理 | 加动效时 |
| `references/qa-checklist.md` | 交付前逐项检查清单 | 交付前 |
| `references/error-log.md` | 实操踩坑与修复记录 | **开工前读一遍**，能省掉一半返工 |
| `references/worked-example-atypica.md` | atypica.ai 的完整拆解（section 地图、实测值、资产清单） | 想看具象样本时 |
| `assets/editorial-tokens.css` | token + 工具类样式表本体 | 由 init 脚本复制，一般不手改 |
| `scripts/init-design-tokens.mjs` | 把样式表铺进目标项目 | 第 0 步 |
