# 动效规范

> 一句话总则：**动效是证明，不是表演。**
> 每个动效都要能回答"它在证明什么"——进场证明内容到达、打字机证明有人在输入、
> 呼吸点证明系统在运行。答不上来的动效删掉。

## 目录

1. 缓动与时长表
2. 进场 reveal
3. 打字机
4. Marquee
5. 思考点 / 状态点
6. Hover
7. reduced-motion 回退
8. 禁止清单

---

## 1. 缓动与时长表

| 动效 | 时长 | 缓动 | 备注 |
|---|---|---|---|
| 进场 reveal | 900ms | `cubic-bezier(.16,1,.3,1)` | 出场感强、末端极缓 |
| stagger | 90ms/项 | — | 超过 4 项要减小到 60ms，否则最后一项太晚 |
| 打字机进 | 68ms/字 | linear | 接近真人打字节奏 |
| 打字机退 | 24ms/字 | linear | 退比进快 3 倍，符合真实编辑行为 |
| 句尾停顿 | 1600ms | — | 给用户读的时间 |
| marquee | 48s | linear | 越慢越贵气 |
| 思考点 | 1200ms | `ease-in-out` | 三点各延迟 0 / 0.15 / 0.3s |
| 光标闪烁 | 1000ms | `steps(1)` | |
| hover | 150–200ms | `ease-out` | 只做 opacity / scale(1.05) / 位移 |

只有一条主缓动曲线 `cubic-bezier(.16,1,.3,1)`——多个不同缓动混用会显得零散。

## 2. 进场 reveal

```css
[data-reveal] {
  opacity: 0;
  transform: translateY(28px);
  transition: opacity .9s cubic-bezier(.16,1,.3,1), transform .9s cubic-bezier(.16,1,.3,1);
  transition-delay: var(--reveal-delay, 0ms);
}
[data-reveal].revealed { opacity: 1; transform: none; }
```

observer 参数：`threshold: 0.12`、`rootMargin: "0px 0px -48px 0px"`（底部内缩，避免元素刚露头就播）。
播完 `unobserve`——**播一次即停**。反复播放会让页面显得 twitchy。

## 3. 打字机

- 3–4 条**真实**文案循环（不要用 "lorem ipsum" 或空泛的口号）。
- 光标 `.at-caret` 跟随。
- 组件实现：一组 `setTimeout` 递推，或 `requestAnimationFrame` + 时间戳；
  卸载时清理 timer（否则路由切换会泄漏）。

## 4. Marquee

```css
.at-marquee { display: flex; width: max-content; animation: at-marquee 48s linear infinite; }
.at-marquee:hover { animation-play-state: paused; }
@keyframes at-marquee { from { transform: translateX(0); } to { transform: translateX(-50%); } }
```

列表必须渲染**两遍**，平移 -50% 才能无缝。hover 暂停是必要的——
用户想看清某个 logo 时它会停下来，这是尊重而不是花哨。

## 5. 思考点 / 状态点

`.at-thinking` 三点呼吸（0 / 0.15 / 0.3s 延迟），用于"agent 正在处理"的位置。
`● 系统运行中` 这类常驻状态点用同样的动画，但放慢到 2s 以免抢注意力。

## 6. Hover

只允许三种：

- logo / 图片：透明度变化（`opacity-60 → 100`、`grayscale → 彩色`）
- 按钮：`opacity / scale(1.05)`
- 链接箭头：`translateX(2~4px)`

## 7. reduced-motion 回退

每一个动画都要有对应的静态分支，两种方式：

```css
@media (prefers-reduced-motion: reduce) {
  [data-reveal] { opacity: 1; transform: none; transition: none; }
  .at-marquee { animation: none; }
}
```

JS 驱动的动效（打字机、轮播自动播放）要在组件里读
`window.matchMedia("(prefers-reduced-motion: reduce)").matches` 并走静态分支。

⚠️ React 19 lint：effect 里**不能同步** setState。写成
`setTimeout(() => setText(first), 0)`，异步回调是合法的。

## 8. 禁止清单

- **bounce / spring / wobble / elastic**：任何"活泼"的缓动都会把高级感打回玩具感。
- 滚动 hijack（接管滚动速度/位置）——用户会立刻失去控制感。
- 视差层数 > 2。
- 无限循环的漂浮动画（漂浮卡是**静态**定位 + 进场动画，不是持续上下浮动）。
- 数字滚动计数动画（除非是真正的实时数据）。
- 鼠标跟随光晕 / 粒子。
- 进场动效超过 1s——900ms 已经是上限。
