# Next.js App Router + Tailwind v4 落地笔记

> 本仓库（`ai-website-cloner-template`）就是这个栈。
> 这一页记的是**版本特有的、会让你卡住半小时**的具体注意点，不是通用教程。

## 目录

1. 版本与脚本
2. Tailwind v4 的 token 写法
3. 字体接入
4. 客户端组件的边界
5. lint / typecheck 常见报错
6. 目录约定
7. 本地起服务

---

## 1. 版本与脚本

- Next.js 16 + React 19 + Tailwind v4 + shadcn/ui。
- `npm run check` = lint + typecheck + build 一起跑（交付前唯一需要记的命令）。
- `npm run lint` / `npm run typecheck` / `npm run build` 可单独跑。
- Next.js 自带离线文档在 `node_modules/next/dist/docs/`——
  API 不确定时**先查这里**，比上网搜快且版本一定对：
  `node_modules/next/dist/docs/01-app/03-api-reference/02-components/font.md`

## 2. Tailwind v4 的 token 写法

v4 不再用 `tailwind.config.js` 定义主题，改为 CSS-first：

```css
@import "tailwindcss";

@theme {
  --color-at-bg: oklch(21% 0.006 285.885);
  --color-at-green: oklch(87% 0.29 142.57);
}
```

- oklch 可以**直接写**在 CSS 变量里，不需要插件。
- 自定义工具类用 `@utility` 或普通 class。
- `@apply` 仍然可用，但 v4 更推荐直接写 CSS。
- 需要作用域隔离时（多个克隆站共存），用一层 wrapper class
  （`.atypica { --at-bg: ... }`）而不是改全局 `:root`。

## 3. 字体接入

`app/layout.tsx`：

```tsx
import { Figtree, Instrument_Serif, IBM_Plex_Mono } from "next/font/google";

const display = Figtree({ subsets: ["latin"], variable: "--font-display" });
const serif   = Instrument_Serif({ subsets: ["latin"], weight: "400", variable: "--font-serif-accent" });
const mono    = IBM_Plex_Mono({ subsets: ["latin"], weight: "400", variable: "--font-mono-alt" });

export default function RootLayout({ children }) {
  return (
    <html className={`${display.variable} ${serif.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```

- `variable` 生成的 CSS 变量名要和你 token 里引用的名字一致，不一致会静默 fallback。
- 中文**不要**加 `subsets: ["chinese"]` 或加载中文 webfont。

## 4. 客户端组件的边界

只有真正需要浏览器 API 的组件才加 `"use client"`：

1. 全局 IntersectionObserver（reveal）
2. 打字机
3. 滚动进度 → active step
4. 轮播

其余全部 server component。判断标准：用到 `window` / `document` / `useEffect` / 事件回调才需要。

## 5. lint / typecheck 常见报错

| 报错 | 原因 | 修法 |
|---|---|---|
| `react-hooks/set-state-in-effect` | effect 里同步 setState | 用 `setTimeout(() => setX(...), 0)` 包裹 |
| `Cannot find module 'xxx/lib/yyy'` | node_modules 损坏 | 删该包 + `.package-lock.json` 重装 |
| JSX 字符串裸换行 | 长中文文案直接回车 | 压平成一行，或 `\n` + `whitespace-pre-line` |
| `<img>` 警告 | 用了原生 img | 像素克隆场景可接受（需要精确尺寸控制）；否则换 `next/image` |

## 6. 目录约定

```
src/app/                         路由
src/components/sites/<site>/     该站点的组件（一个 section 一个文件）
public/sites/<site>/assets/      资产
docs/research/<site>/            研究证据（page-brief / page-text / shots）
scripts/download-<site>-assets.sh
```

不同源站用不同的 `<site>` 命名空间，字体与样式通过 wrapper class 隔离。

## 7. 本地起服务

```bash
npm run build
node node_modules/next/dist/bin/next start -p 3100    # 用后台任务跑，不要用 nohup &
bash <skill>/scripts/check-local.sh 3100 --wait 20    # --noproxy + 127.0.0.1
```

常见坑见 `error-log.md` #3（代理 502）与 #5（nohup 起不来）。
