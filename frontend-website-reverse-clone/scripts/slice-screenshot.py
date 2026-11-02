#!/usr/bin/env python3
"""
slice-screenshot.py — 把超长整页截图切成 N 段，便于逐段阅读。

为什么需要它：
  一个 10000px 高的整页截图直接喂给视觉模型，要么被下采样到看不清字，
  要么超长被截断。切成 8–12 段、每段缩到 640–720px 宽，是能真正"看清"的甜点。

  注意：本脚本只解决"图太长看不清"的问题，不解决"图是黑的"的问题。
  滚动触发型站点的整页截图大部分是黑的 —— 那个要靠真实滚动逐段截图，
  见 website-reverse-clone SKILL.md 阶段 2。

用法：
  python3 slice-screenshot.py full.png --bands 10
  python3 slice-screenshot.py full.png --bands 8 --width 720 --outdir bands
  python3 slice-screenshot.py full.png --height 1200        # 按固定像素高切而不是等分
"""

import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit(
        "✗ 需要 Pillow。用受管 venv：\n"
        "  ~/.workbuddy/binaries/python/envs/default/bin/pip install pillow\n"
        "  ~/.workbuddy/binaries/python/envs/default/bin/python3 slice-screenshot.py ..."
    )


def main():
    ap = argparse.ArgumentParser(description="把长截图切成若干段")
    ap.add_argument("input", help="输入图片路径")
    ap.add_argument("--bands", type=int, default=10, help="等分切成 N 段（默认 10）")
    ap.add_argument("--height", type=int, default=0, help="按固定像素高切（优先于 --bands）")
    ap.add_argument("--width", type=int, default=720, help="每段缩放到的宽度（默认 720）")
    ap.add_argument("--outdir", default=None, help="输出目录，默认与输入同目录")
    args = ap.parse_args()

    src = os.path.abspath(args.input)
    if not os.path.isfile(src):
        sys.exit(f"✗ 找不到 {src}")

    outdir = os.path.abspath(args.outdir) if args.outdir else os.path.dirname(src)
    os.makedirs(outdir, exist_ok=True)

    img = Image.open(src)
    w, h = img.size
    step = args.height if args.height > 0 else max(1, h // args.bands)

    n, i, top = 0, 0, 0
    while top < h:
        bottom = min(h, top + step)
        crop = img.crop((0, top, w, bottom))
        nw = min(args.width, w)
        nh = max(1, int((bottom - top) * nw / w))
        crop = crop.resize((nw, nh), Image.LANCZOS)
        name = f"band-{i:02d}.png"
        crop.save(os.path.join(outdir, name))
        print(f"ok {name}  {nw}x{nh}  (y {top}–{bottom})")
        i += 1
        top = bottom
        n += 1

    print(f"— 共 {n} 段 → {outdir}")


if __name__ == "__main__":
    main()
