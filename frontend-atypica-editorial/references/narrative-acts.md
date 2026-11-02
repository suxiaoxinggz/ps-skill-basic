# 10 幕分镜脚本

> SKILL.md 第 3 节是索引表，这里是每一幕的完整施工脚本：职责、文案结构、尺寸、响应式降级。
> 幕的**顺序**就是叙事节奏，不要重排——第 5 幕（产品演示）必须在社会证明之后、
> 数据在之前，因为"先证明 → 再展示 → 再给证据"才是最短的可信路径。

## 目录

- 幕 1 公告条
- 幕 2 导航
- 幕 3 Hero
- 幕 4 信任条
- 幕 5 产品演示（最重）
- 幕 6 评估 / 指标
- 幕 7 报告 / 产出
- 幕 8 模型 / 方法论
- 幕 9 客户案例
- 幕 10 CTA
- 幕 11 Footer
- 全局件：悬浮输入条
- 响应式总原则

---

## 幕 1 公告条

**职责**：一条"我们还活着、还在更新"的信号。30px 高，不抢戏。

- 深灰全宽条（`bg-white/[0.04]` 或 `--at-muted`），居中文案 13px，链接带下划线。
- 右侧 × 可关闭（用 state，刷新后不恢复更真实）。
- 移动端文案截断为一行 + `text-ellipsis`。

## 幕 2 导航

**职责**：收敛注意力。全站唯一常驻的 UI。

- `sticky top-0 z-50` + `backdrop-blur` + `bg-[--at-bg]/80`（滚动后才需要不透明）。
- 高 **56px**。logo 后半段用 accent（`atypica.`**`AI`**）。
- 3 个带下拉 chevron 的菜单 + 1 个纯链接 + 右侧**实底 CTA**（白底黑字，全站唯一实底按钮）。
- 移动端：logo + 汉堡，菜单收进抽屉。

## 幕 3 Hero（定调幕）

**职责**：一句话定调——这是电影，不是模板。整页预算的 30% 应该花在这。

结构（从下往上叠）：

```
<section relative min-h-[calc(100vh-3.5rem)] overflow-hidden>
  <video 全屏 object-cover absolute inset-0 autoPlay muted loop playsInline poster={LCP 图} />
  <div 渐晕: linear-gradient(180deg, bg/78% → bg/35% 40% → bg/88%) />   ← 双层，保证文字可读
  <漂浮玻璃卡 ×3–4  absolute  hidden md:block />                        ← 四周，避开文字区
  <内容流 左下: badge pill → h1 → 说明段 → 输入条 />
</section>
```

- **视频必须是实拍 / 摄影感**。人物、场景、真实光线。3D 渲染和粒子背景直接判定不合格。
- 渐晕两层：一层压顶部导航区，一层压底部文字区。
- 漂浮卡内容结构：英文卡题（13px）+ 一句话（12px / 白 65%）+ 绿点 pill（10px）。
- 漂浮卡定位经验值（1440 视口）：`left-[38%] top-[12%]`、`right-[4%] top-[28%]`、
  `right-[12%] top-[44%]`、`left-[58%] top-[74%]`。**必须避开 h1 文字区**，
  压住标题是这里最常见的失误。小屏全部隐藏。

## 幕 4 信任条

**职责**：社会证明，一笔带过（不超过 240px 高）。

- eyebrow：全大写 + letterspacing `0.08em`，白 60%。
- marquee：logo 列表 ×2，`width: max-content`，48s 平移 -50%，hover 暂停。
- logo 一律 `grayscale opacity-60`（hover 才恢复）。彩色 logo 会毁掉暗色版式。

## 幕 5 产品演示（全页最重）

**职责**：证明产品会做什么。这一幕做砸了，后面全部白搭。

布局：

```
<section>
  <intro: grid md:grid-cols-[1fr_1.4fr]  eyebrow + h2 | 说明段 />
  <div ref className="relative md:h-[400vh]">                    ← 滚动轨道
    <div className="md:sticky md:top-14 md:flex md:h-[calc(100vh-3.5rem)] md:gap-10">
      <左栏 w-[300px]> 大编号 + 步骤题 + 描述 + mt-auto mini 标签 </左栏>
      <MacFrame> activeStep 对应的演示面板 </MacFrame>
    </div>
  </div>
</section>
```

- 步骤数决定轨道高度：`n × 100vh`（4 步 = 400vh）。
- active step：`progress = clamp((-rect.top) / (rect.height - viewportH), 0, 1)`，
  `active = floor(progress * n)`，末段要 clamp 到 `n-1`。
- 左栏底部 mini 标签行：`问题 · 对象 · 方法`，10px / uppercase / 白 40% / 中点分隔。

**窗口框 chrome**：三个 `bg-white/20` 圆点 → 品牌行（logo + 绿点 + 点数计数器）→ 内容区。
点数计数器（如 `1,240 点数`）是个廉价但极其有效的"这东西在跑"信号。

**四个演示面板的配方**（这是 product-proof 的核心）：

1. **产品视频**：循环 mp4，配 poster。最简单，但别全用它——四个面板都是视频就没有"证据感"了。
2. **终端日志 + Persona 网格**：mono 绿色 `› exec makeStudyPlan` 行 + 右侧 persona 卡片
   （色环头像 + 姓名 + 类型 pill + 两行评论），网格 `grid-cols-2 gap-2`。
3. **焦点小组聊天流**：6 人头像 + 气泡发言，底部结论条 `bg-white/[0.04]` + 「查看原因」。
4. **决策卡**：选项列表（选中项 `border-green/40 bg-green/10`）+ 研究方案 bullet + insight 引语。

通用底栏：`进度 3/7 · Panel 6` + `.at-thinking` 呼吸三点。

**Persona 头像**：`oklch(78% 0.12 <hue>)` 色环 + 首字母，不要依赖外部头像服务（会挂、会拖慢）。

**移动端降级**：轨道改正常文档流，编号下加横向进度条，左右栏改上下堆叠。

## 幕 6 评估 / 指标

**职责**：用数据接住上一幕的演示。

- 三列**反相白纸卡**：`rounded-lg bg-white p-1` + 内嵌图表图（`aspect-[16/10] object-cover`）。
- 四角绿色工程十字标 `.at-tick`（6px 方块，`left/top` 四个角）。
- 卡下：题目（16–20px / 500）+ 说明（13px / 白 70%）。
- 移动端单列堆叠。

## 幕 7 报告 / 产出

**职责**：让用户看到"我最后拿到的是什么"。

- 左：文案 + 绿勾 2×2 清单 + 「查看一份真实报告 →」（下划线链接 + 箭头位移 hover）。
- 右：透视倾斜的白纸报告 mock
  `transform: perspective(1200px) rotateX(4deg) rotate(2deg)` + `.at-lift` 深投影。
- 学术论文变体：多张 ±2~3° 交替旋转错位排布。

## 幕 8 模型 / 方法论

**职责**：回答"凭什么可信"。

- 背景：`.at-grid-bg`（56px 工程网格，白 3%）。
- h2 内嵌**衬线强调词**（`.font-serif-accent`，白色，一个词或短语即可）。
- 左列白色引语卡：serif 引号 `text-white/25 text-4xl` + 正文 18px/32px + 绿点署名。
- 右：轮播面板，白底内容卡 `min-h-[190px]`（防切换跳动）+ mono 页码 `01/04`
  + 前后箭头 + 圆点，受控切换。

## 幕 9 客户案例

**职责**：落到具体的人与公司。

- 暗卡 `border-white/10 bg-white/[0.03] rounded-xl p-6`。
- 结构：灰度大 logo（`grayscale opacity-80`）+ 右上「方向」pill + serif 引号 +
  引语 + `mt-auto` 的 meta 行。
- 卡面可加绿色角标。

## 幕 10 CTA

**职责**：全站唯一一次情绪上扬。

- `.at-glow` 径向辉光层（唯一一次发光）。
- 四周倾斜漂浮数据卡（同 Hero 配方，`rotate ±2~6°`）。
- 居中大输入条 + 白色实底按钮。
- **注意**：这一幕自带 in-flow 输入条，所以全局悬浮条必须在这里淡出。

## 幕 11 Footer

**职责**：收尾 + 索引。

- `grid lg:grid-cols-[1.2fr_2fr]`。
- 品牌列：slogan / 版权 / 社交图标 / `● 系统运行中` 状态点（绿点 + 呼吸动画）。
- 4 列链接 `text-[13px] text-white/55`。

## 全局件：悬浮输入条

```
fixed bottom-6 left-1/2 z-30 w-[min(42rem,calc(100%-2.5rem))] -translate-x-1/2
rounded-2xl border-white/15 bg-black/70 backdrop-blur-md
```

- 内容：打字机循环 3–4 条**真实**研究问题 + 右侧「免费开始研究 →」。
- 淡出：IntersectionObserver 监听 `#cta`（threshold 0.2），可见时 `opacity-0 pointer-events-none`。
- ⚠️ **不要做成 section 内 sticky**——滚出所属 section 后会顶在内容上（真实踩坑，见 error-log #3）。

## 响应式总原则

1. 漂浮卡、网格背景、透视倾斜：`< md` 全部关掉或简化。
2. 滚动步进轨道：`< md` 降级为普通文档流 + 进度条。
3. 多列网格：`< md` 一律单列。
4. 字号用 `clamp()` 而不是断点切换，能少写一半媒体查询。
5. 检查**横向溢出**：`document.documentElement.scrollWidth <= window.innerWidth`。
