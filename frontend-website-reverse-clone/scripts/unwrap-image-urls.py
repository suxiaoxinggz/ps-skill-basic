#!/usr/bin/env python3
"""
unwrap-image-urls.py — 把被包装过的图片 URL 还原成可直接 curl 的原始地址。

为什么需要它：
  Next.js 站的 img.src 通常是 `/_next/image?url=<encoded>&w=1920&q=75`，
  直接下载会拿到源站转码后的格式（常常是 AVIF/WebP），而不是你在页面里看到的那张图，
  甚至会因为缺少合法 w/q 参数而 400。S3/CDN 类站点还会再套一层 `?objectUrl=<encoded>`。
  本脚本把这两层（以及它们的嵌套组合）剥掉，输出去重后的原始 URL 列表。

用法：
  python3 unwrap-image-urls.py asset-urls.json
  python3 unwrap-image-urls.py asset-urls.json --origin https://example.com
  python3 unwrap-image-urls.py urls.txt --json          # 输出 JSON 数组
  python3 unwrap-image-urls.py urls.txt --out originals.txt

输入接受三种格式（自动识别）：
  1. JSON 数组：["https://a/b.png", ...]
  2. JSON 对象：{"urls": [...], "vids": [...]}  （浏览器采集脚本的常见输出）
  3. 纯文本：一行一个 URL
"""

import argparse
import json
import re
import sys
from urllib.parse import unquote, urlparse, urljoin

# 需要剥掉的参数名（按优先级尝试）
WRAPPERS = ("url", "objectUrl", "src", "image", "file")


def collect_strings(node, out):
    """递归收集 JSON 里所有看起来像 URL 的字符串。"""
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, dict):
        for v in node.values():
            collect_strings(v, out)
    elif isinstance(node, list):
        for v in node:
            collect_strings(v, out)


def load_input(path):
    raw = open(path, "r", encoding="utf-8").read().strip()
    if not raw:
        return []
    if raw.startswith("[") or raw.startswith("{"):
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return [l.strip() for l in raw.splitlines() if l.strip()]
        out = []
        collect_strings(data, out)
        return out
    return [l.strip() for l in raw.splitlines() if l.strip()]


def unwrap_once(u):
    """剥一层包装，返回 (是否剥了, 结果)。"""
    parsed = urlparse(u)
    qs = parsed.query
    if not qs:
        return False, u
    for key in WRAPPERS:
        m = re.search(r"(?:^|&)" + re.escape(key) + r"=([^&]+)", qs)
        if m:
            inner = unquote(m.group(1))
            if inner.startswith("http") or inner.startswith("/") or inner.startswith("//"):
                return True, inner
    return False, u


def unwrap(u, origin=None, max_depth=6):
    cur = u.strip()
    for _ in range(max_depth):
        changed, nxt = unwrap_once(cur)
        if not changed or nxt == cur:
            break
        cur = nxt
    # 相对路径补全
    if origin and cur.startswith("/"):
        cur = urljoin(origin, cur)
    elif origin and cur.startswith("//"):
        cur = "https:" + cur
    return cur


def main():
    ap = argparse.ArgumentParser(description="还原被包装的图片/视频 URL")
    ap.add_argument("input", help="URL 清单文件（JSON 数组 / JSON 对象 / 纯文本）")
    ap.add_argument("--origin", default=None, help="用于补全相对路径的站点 origin")
    ap.add_argument("--json", action="store_true", help="输出 JSON 数组而不是每行一个")
    ap.add_argument("--out", default=None, help="写入文件而不是 stdout")
    ap.add_argument("--include-data", action="store_true", help="保留 data: / blob: URI（默认丢弃）")
    args = ap.parse_args()

    urls = load_input(args.input)
    seen, result = set(), []
    for u in urls:
        if not args.include_data and (u.startswith("data:") or u.startswith("blob:")):
            continue
        if not (u.startswith("http") or u.startswith("/") or u.startswith("//")):
            continue
        o = unwrap(u, args.origin)
        if o not in seen:
            seen.add(o)
            result.append(o)

    if args.json:
        text = json.dumps(result, ensure_ascii=False, indent=1)
    else:
        text = "\n".join(result)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print(f"✓ {len(result)} 条 → {args.out}", file=sys.stderr)
    else:
        print(text)

    print(f"— 输入 {len(urls)} 条，去重后 {len(result)} 条", file=sys.stderr)


if __name__ == "__main__":
    main()
