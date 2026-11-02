# 资产管线

> 克隆的质感有一半来自"用的是源站那张图"。用占位图或重新生成的近似图，
> 页面一眼就假。这一页讲怎么把源站资产完整、正确地搬到本地。

## 目录

1. 为什么 URL 要还原
2. 还原与下载的标准动作
3. 目录约定
4. 视频
5. 字体
6. 格式陷阱
7. 校验

---

## 1. 为什么 URL 要还原

两种常见包装：

```
/_next/image?url=https%3A%2F%2Fs3...%2Fhero.jpg&w=1920&q=75     ← Next.js 图片优化代理
https://cdn.x.com/p?objectUrl=https%3A%2F%2Fs3...%2Fdemo.mp4     ← CDN 对象包装
```

直接 curl 这两种 URL：

- 拿到的可能是源站转码后的 **AVIF/WebP**，而不是页面里那张图；
- 缺少合法的 `w`/`q` 组合会直接 **400**；
- 有时还会带上防盗链校验。

所以需要剥掉包装拿到原始地址。

## 2. 还原与下载的标准动作

```bash
# 1) 采集（配方见 capture-recipes.md 第 5 条），落盘 asset-urls.json
# 2) 还原
python3 <skill>/scripts/unwrap-image-urls.py asset-urls.json --origin https://源站.com > originals.txt
# 3) 下载（带重试、content-type 报告、失败清单）
bash <skill>/scripts/fetch-assets.sh originals.txt public/sites/<site>/assets
```

`unwrap-image-urls.py` 会循环剥最多 6 层包装，去重，并把 `data:`/`blob:` 丢掉。
`--origin` 用于把 `/assets/x.png` 这类相对路径补全成绝对地址。

`fetch-assets.sh` 每个文件下载后都会 `file -b --mime-type` 报告真实类型——
**这一步不是装饰**，它能在 Build 之前就暴露"你以为拿到 png 其实是 avif"的问题。

失败清单写在 `<DEST>/.failed.txt`，不要忽略它。

## 3. 目录约定

本仓库：

```
public/sites/<site>/assets/
├── hero-bg-video.mp4 / hero-poster.jpg
├── product-demo.mp4 / product-demo-poster.jpg
├── logos/      # 客户 logo（grayscale 处理前先保留原图）
├── eval/       # 图表
├── report/     # 报告纸面
└── concept/    # 概念图
```

研究文档：

```
docs/research/<site>/
├── page-brief.md        # 唯一事实来源：section 地图 + tokens + 字体 + 字号 + 资产清单 + 动效
├── page-text.md         # 全文案 dump
├── asset-urls.json      # 采集原始输出
└── shots/               # 截图（命名带视口 + y 坐标）
```

下载脚本留一份在仓库 `scripts/download-<site>-assets.sh`，让下次能重跑。
**把下载脚本本身也交付出去**——资产是会失效的，可重跑比已下好的文件更值钱。

## 4. 视频

采集时要记录的不只是 src：

```js
{ src, poster, muted, loop, autoplay, playsInline }
```

- **必须有 poster**，它是 LCP 图；没有 poster 的话自己截首帧生成一张。
- 落地时四个属性缺一不可：`autoPlay muted loop playsInline`——
  少了 `muted` 浏览器会拒绝自动播放，少了 `playsInline` iOS 会强制全屏。
- 体积 > 5MB 要转码（H.264 + 适当 crf），否则首屏会被拖死。
- 源站常有多个编码版本（`-1` / `-3` 后缀），选体积和清晰度平衡的那个。

## 5. 字体

- 从 `fontsUsed` 拿到清单后，先判断哪些是**付费字体**。
- 付费字体找 metrics 接近的免费替代（例如 EuclidCircularA → Figtree / Manrope）。
- **中文一律不加载 webfont**，走系统回退。中文 webfont 动辄 5–10MB，是首屏杀手，
  而且系统字体在大多数版式里观感更好。
- 替代后要**逐屏比对字宽**——不同字体的字宽差异会让换行位置全变。

## 6. 格式陷阱

| 陷阱 | 表现 | 处理 |
|---|---|---|
| `.png` URL 返回 AVIF | 浏览器能显示，本地管线报错 | 用 `fetch-assets.sh` 的 content-type 报告提前发现 |
| SVG logo 被转成 webp | 放大后糊 | 优先找 `.svg` 原件 |
| 响应式 `srcset` 只拿到最小的 | 克隆出来是糊的 | 采集时读 `currentSrc`，并按最大 `w` 还原 URL |
| lazyload 图片没采集到 | 滚动前 `src` 为空 | 先滚一遍再采集 |
| 资产带防盗链 Referer | curl 403 | 加 `-H "Referer: https://源站/"` |

## 7. 校验

下载完先做三件事再开始 Build：

1. `ls -la` 看有没有 0 字节文件（有就是断流，重下）。
2. 抽查 2–3 张图的尺寸是否和页面里显示的比例一致。
3. 把 `.failed.txt` 里的 URL 单独处理（换 UA / 加 Referer / 手动存）。
