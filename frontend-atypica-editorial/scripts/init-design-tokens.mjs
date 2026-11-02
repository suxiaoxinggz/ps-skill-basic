#!/usr/bin/env node
/**
 * init-design-tokens.mjs
 *
 * 把 editorial-cinematic 的 token 与工具类样式表铺进目标项目。
 * 之所以用脚本而不是让人手抄：样式表里有 12 个相互依赖的工具类，
 * 抄漏一个（比如 [data-reveal].revealed）就会得到"页面一片空白"这种极难排查的 bug。
 *
 * 用法：
 *   node init-design-tokens.mjs --target ./src/app
 *   node init-design-tokens.mjs --target ./styles --scope editorial
 *   node init-design-tokens.mjs --target ./src/app --force
 *
 * 参数：
 *   --target <dir>   目标目录（必须已存在）
 *   --scope <class>  作用域 class 名，默认 atypica
 *   --force          已存在时覆盖
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = { target: null, scope: "atypica", force: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--target") args.target = argv[++i];
    else if (a === "--scope") args.scope = argv[++i];
    else if (a === "--force") args.force = true;
    else if (a === "--help" || a === "-h") args.help = true;
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));

if (args.help || !args.target) {
  console.log(`用法: node init-design-tokens.mjs --target <dir> [--scope <class>] [--force]`);
  process.exit(args.help ? 0 : 1);
}

const targetDir = resolve(args.target);
if (!existsSync(targetDir) || !statSync(targetDir).isDirectory()) {
  console.error(`✗ 目标目录不存在或不是目录: ${targetDir}`);
  process.exit(1);
}

const src = join(__dirname, "..", "assets", "editorial-tokens.css");
if (!existsSync(src)) {
  console.error(`✗ 找不到源样式表: ${src}`);
  process.exit(1);
}

let css = readFileSync(src, "utf8");

// 作用域 class 重命名：把 .atypica 替换成自定义 scope
if (args.scope !== "atypica") {
  css = css.replace(/\.atypica\b/g, `.${args.scope}`);
  css = css.replace(/"atypica"/g, `"${args.scope}"`);
}

const outPath = join(targetDir, `editorial-tokens.css`);
if (existsSync(outPath) && !args.force) {
  console.error(`✗ 已存在 ${outPath}。加 --force 覆盖，或换个 --target。`);
  process.exit(1);
}

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, css, "utf8");

console.log(`✓ 已写入 ${outPath}  (scope: .${args.scope})\n`);
console.log(`接下来三步（顺序不能乱）：\n`);
console.log(`1) import 进全局样式。`);
console.log(`   Tailwind v4 —— 在你的 globals.css 顶部加：`);
console.log(`     @import "./editorial-tokens.css";`);
console.log(`   Tailwind v3 / 非 Tailwind —— 在入口 tsx 里 import "${args.scope}/editorial-tokens.css" 的等价路径。\n`);
console.log(`2) 接字体。Next.js App Router 的 layout.tsx：`);
console.log(`     import { Figtree, Instrument_Serif, IBM_Plex_Mono } from "next/font/google";`);
console.log(`     const display = Figtree({ subsets: ["latin"], variable: "--font-display" });`);
console.log(`     const serif   = Instrument_Serif({ subsets: ["latin"], weight: "400", variable: "--font-serif-accent" });`);
console.log(`     const mono    = IBM_Plex_Mono({ subsets: ["latin"], weight: "400", variable: "--font-mono-alt" });`);
console.log(`     // <html className={\`${display.variable} ${serif.variable} ${mono.variable}\`}>`);
console.log(`   非 Next.js：用 @font-face 或 CSS import，变量名保持一致即可。`);
console.log(`   注意：中文不加载 webfont，靠 system-ui 回退。\n`);
console.log(`3) 给页面根元素加作用域 class：`);
console.log(`     <body className="${args.scope}">   或   <div className="${args.scope}">…</div>\n`);
console.log(`然后去 references/component-recipes.md 按幕施工。`);
