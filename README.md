# ps-skill-basic

自用 Agent Skills 合集。每个 skill 是一个独立顶层目录，遵循 [Agent Skills 规范](https://agentskills.io/specification)，可被 Claude Code / Cursor / Codex / Gemini CLI / Antigravity / pi 等支持 `SKILL.md` 的 agent 直接加载。

## Skills

| Skill | 用途 | 需要 API Key |
|---|---|---|
| [`frontend-design-workflow`](frontend-design-workflow/) | 强制式前端设计全流程编排：设计阅读 → 设计智能 → 设计系统落库 → 实现 → 工艺评审 → 运行时浏览器验证，六阶段消除 "AI slop" | ❌ |
| [`frontend-atypica-editorial`](frontend-atypica-editorial/) | 杂志式 SaaS 设计 × 电影感视觉叙事 × 交互式产品演示的设计语言，适用于高质感 AI/SaaS 官网首页与暗色 editorial 版式 | ❌ |
| [`frontend-website-reverse-clone`](frontend-website-reverse-clone/) | 逆向克隆已存在网页：Map → Observe → Extract → Build → Compare → QA 六阶段，含采集与资产还原脚本，产出可编辑本地代码 | ❌ |
| [`macos-app-dual-clone`](macos-app-dual-clone/) | macOS 应用双开/多开分身：克隆 `.app` 改 BundleID 重签 + 钥匙串 `-34018` 修复 + Electron 单实例锁处理（微信 / Muse / WorkBuddy 实测） | ❌ |
| [`multi-search-engine`](multi-search-engine/) | 多搜索引擎聚合，17 个引擎（8 国内 + 9 海外），支持高级搜索算子、时间过滤、站内搜索、隐私引擎 | ❌ |

## 安装

```bash
git clone https://github.com/suxiaoxinggz/ps-skill-basic.git
```

按你使用的 agent 选目标目录，**整个 skill 目录**拷过去（父目录是容器，`SKILL.md` 才是 skill 本体）：

```bash
# Claude Code
cp -r ps-skill-basic/macos-app-dual-clone ~/.claude/skills/

# pi（用户级）
cp -r ps-skill-basic/macos-app-dual-clone ~/.pi/agent/skills/

# 通用 Agent Skills 位置（pi / 多数兼容 agent 都会读）
cp -r ps-skill-basic/macos-app-dual-clone ~/.agents/skills/

# Codex
cp -r ps-skill-basic/macos-app-dual-clone ~/.codex/skills/

# Cursor
cp -r ps-skill-basic/macos-app-dual-clone ~/.cursor/skills/

# Gemini CLI / Antigravity
cp -r ps-skill-basic/macos-app-dual-clone ~/.gemini/config/skills/
```

只想装一个？把上面命令里的目录名换掉即可。装完后**重启 agent**，skill 列表才会重新扫描。

## 目录约定

每个 skill 目录的结构：

```
<skill-name>/
├── SKILL.md            # 必需。YAML frontmatter: name + description，正文是执行指令
├── metadata.json       # 本仓库约定：name / version / description / author / requires_api_key
├── README.md           # 可选，人类可读说明
├── scripts/            # 可选，可直接执行的脚本
├── references/         # 可选，按需加载的详细文档 / 排错手册
├── assets/             # 可选，模板、图标等静态资源
└── evals/              # 可选，评测用例
```

`SKILL.md` 的 `description` 决定 agent 什么时候主动调用它 —— 写清"何时用"，比写清"是什么"更重要。

## 兼容性

- **SKILL.md 格式**：Anthropic Agent Skills 规范，Claude Code / Cursor / Codex / Gemini CLI / pi 通用。
- **脚本**：目前都是 bash + python3，macOS / Linux 可跑；`macos-app-dual-clone` 仅限 macOS。
- **无外部服务依赖**：以上 skill 均不需要 API Key。

## License

个人自用，未附许可证。转载或复用请先联系作者。
