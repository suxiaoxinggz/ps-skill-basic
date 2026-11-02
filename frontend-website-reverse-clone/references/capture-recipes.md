# 浏览器采集配方（paste 即用）

> 下面每段都是**可以直接粘进浏览器 evaluate 工具**的 JS 函数体。
> 用 MCP playwright 时传 `function: "() => { … }"`；用 `playwright` npm 包时放进 `page.evaluate()`。
> 需要落盘的配合工具的 `filename` 参数。

## 目录

1. Section 地图（必须先做）
2. Computed styles + CSS 变量
3. 字体清单
4. 全文案 dump
5. 资产 URL 清单（含视频）
6. 全站 background-image
7. 真实滚动逐段截图的正确顺序
8. 横向溢出检测

---

## 1. Section 地图（必须先做）

**为什么先做这个**：后面所有定点截图都要 y 坐标。没有地图就只能盲滚，
盲滚会漏掉 section（尤其是高的 sticky 场景）。

```js
() => {
  const secs = [...document.querySelectorAll('section, [data-section], main > div')];
  return {
    pageHeight: document.body.scrollHeight,
    sections: secs.map((s, i) => {
      const r = s.getBoundingClientRect();
      return {
        i,
        tag: s.tagName,
        cls: (s.className || '').toString().slice(0, 80),
        top: Math.round(r.top + window.scrollY),
        h: Math.round(r.height),
        text: (s.innerText || '').replace(/\s+/g, ' ').slice(0, 80)
      };
    }).filter(s => s.h > 50)
  };
}
```

看到 `h` 远大于视口高度（比如 3600px）的 section，几乎可以断定是 sticky 滚动场景——
重点对象。

## 2. Computed styles + CSS 变量

```js
() => {
  const pick = (el) => {
    const cs = getComputedStyle(el);
    return {
      font: cs.fontFamily, size: cs.fontSize, weight: cs.fontWeight,
      lh: cs.lineHeight, ls: cs.letterSpacing, color: cs.color,
      bg: cs.backgroundColor, radius: cs.borderRadius, pad: cs.padding
    };
  };
  const r = {};
  r.body = pick(document.body);
  const h1 = document.querySelector('h1');
  r.h1 = h1 ? { text: h1.innerText, ...pick(h1) } : null;
  r.h2s = [...document.querySelectorAll('h2')].slice(0, 8)
    .map(h => ({ t: h.innerText?.slice(0, 60), ...pick(h) }));
  r.h3s = [...document.querySelectorAll('h3')].slice(0, 10)
    .map(h => ({ t: h.innerText?.slice(0, 60), ...pick(h) }));
  const p = document.querySelector('p');
  r.p0 = p ? pick(p) : null;
  const btn = [...document.querySelectorAll('button, a')]
    .find(e => /试用|开始|Start|Get/.test(e.textContent || ''));
  r.cta = btn ? { text: btn.innerText, ...pick(btn) } : null;

  const root = getComputedStyle(document.documentElement);
  r.cssVars = {};
  for (const n of ['--background','--foreground','--primary','--accent','--radius',
                   '--font-sans','--font-mono','--muted','--border','--card']) {
    const v = root.getPropertyValue(n);
    if (v) r.cssVars[n] = v.trim();
  }
  return r;
}
```

## 3. 字体清单

```js
() => {
  const fonts = new Set();
  document.querySelectorAll('*').forEach(e => {
    const f = getComputedStyle(e).fontFamily;
    if (f) fonts.add(f.split(',')[0].replace(/"/g, ''));
  });
  return [...fonts];
}
```

拿到清单后要判断哪些是**付费字体**——付费的要找免费替代（metrics 接近的），
不能硬加载（会 404 或 fallback 到完全不同的字形）。

## 4. 全文案 dump

```js
() => {
  return [...document.querySelectorAll('section')]
    .map((sec, i) => `\n\n===== SECTION ${i} (${(sec.className||'').toString().slice(0,60)}) =====\n`
      + (sec.innerText || ''))
    .join('');
}
```

⚠️ 内容很长时**分段 dump**（比如 `.slice(0, 6)` 与 `.slice(6)`），
一次性 dump 两万字容易被截断，而截断处的丢失往往察觉不到。

## 5. 资产 URL 清单（含视频）

```js
() => {
  const urls = [...new Set([...document.querySelectorAll('img')]
    .map(i => i.currentSrc || i.src).filter(u => u && u.startsWith('http')))];
  const vids = [...new Set([...document.querySelectorAll('video')]
    .map(v => ({ src: v.currentSrc || v.src, poster: v.poster,
                 muted: v.muted, loop: v.loop, autoplay: v.autoplay }))
    .filter(v => v.src))];
  return JSON.stringify({ urls, vids }, null, 1);
}
```

⚠️ 见 asset-pipeline.md：Next.js 站的 URL 是 `_next/image` 包装，必须先还原。

## 6. 全站 background-image

```js
() => {
  const out = [];
  document.querySelectorAll('*').forEach(e => {
    const b = getComputedStyle(e).backgroundImage;
    if (b && b.includes('url(') && out.length < 20) {
      out.push({ el: e.tagName + '.' + (e.className || '').toString().slice(0, 40), bg: b.slice(0, 160) });
    }
  });
  return out;
}
```

注意：渐变里的 `url()` 和真实图片要区分；`background-size`/`position` 也要一起记，
否则重建时裁切位置会错。

## 7. 真实滚动逐段截图的正确顺序

**不要**：

```js
page.screenshot({ fullPage: true })   // 滚动触发型站点 → 大部分全黑
```

**要**：

```js
// 1) 拿到 section 地图（见配方 1）
// 2) 对每个 section 的 top：
() => { window.scrollTo(0, <top>); return document.body.scrollHeight; }
// 3) 等 600–900ms（等进场动画播完 + 图片 lazyload）
// 4) screenshot（非 fullPage）
```

补充：

- 视口**先固定**（如 1440×900），否则 sticky 的 `top` 偏移会变。
- sticky 场景要在**多个滚动位置**截图（进入 / 中段 / 退出），才能看出步进逻辑。
- 每段截图命名带 y 坐标：`sec-<name>-y2400.png`。

## 8. 横向溢出检测

```js
() => ({
  scrollWidth: document.documentElement.scrollWidth,
  innerWidth: window.innerWidth,
  overflow: document.documentElement.scrollWidth > window.innerWidth,
  culprits: [...document.querySelectorAll('*')]
    .filter(e => e.getBoundingClientRect().right > window.innerWidth + 2)
    .slice(0, 10)
    .map(e => e.tagName + '.' + (e.className || '').toString().slice(0, 50))
})
```

在 375 / 768 / 1440 各跑一次。克隆出来的横向溢出 90% 来自
`w-[Npx]` 硬宽度或 marquee 的 `max-content`。
