# Claude Code 用量 → MacBook Pro Touch Bar

将 Mac Mini 上 Claude Code 的 5h/7d 用量配额实时显示在 MacBook Pro 的 Touch Bar 上。

## 原理

```
Mac Mini                        iCloud Drive               MacBook Pro
───────                         ────────────               ───────────
Claude Code statusline hook     claude-usage/state.json    MTMR shellScript
→ export.py 提取 rate_limits    ←────────→                 → touchbar-fetch.sh
→ 写入 iCloud                                        → Touch Bar 彩色进度条
```

数据通过 iCloud Drive 自动同步，不需要两台机器在同一局域网。Claude Code 每轮对话结束后触发导出，MTMR 每 3 秒轮询一次读取最新数据。

## Touch Bar 显示说明

```
5H ███▊·····  38% ↺3h25m  ┃  7D ██▌······  22% ↺5d12h  ●
    ├── progress ──┤ ├──┤      ├── progress ──┤ ├──┤     │
    80级渐变进度条   百分比     80级渐变进度条   倒计时    连线状态
```

| 元素 | 含义 |
|------|------|
| `5H` / `7D` | 5 小时 / 7 天滑动窗口（亮青色粗体） |
| `██▊·····` | 80 级丝滑进度条，用 1/8 Unicode block（█▉▊▋▌▍▎▏）渲染，10 格 × 8 子级 |
| `·` 网格点 | 空白区域底纹，保持科幻仪表盘质感 |
| `38%` | 精确百分比（整数，右对齐 3 位） |
| `↺3h25m` | 距离额度重置的倒计时，归零时显示 `✧` |
| `●` / `○` | 连线指示灯（含义见下表） |
| `┃` | 间隔线，视觉分隔两个窗口 |

### 进度条渐变色

```
0% ░░░░░░░░░░ 100%
青 → 亮白 → 黄 → 红 → 亮紫
```

| 颜色 | 进度范围 | 含义 |
|------|---------|------|
| 🩵 青 | 0-30% | 用量极低 |
| 🤍 亮白 | 30-50% | 正常 |
| 💛 黄 | 50-70% | 过半 |
| ❤️ 亮红 | 70-90% | 告警 |
| 💜 亮紫 | 90-100% | 即将耗尽 |

### 连线指示灯

| 显示 | 最后更新 | 含义 |
|------|---------|------|
| 🟢 `●` 亮绿 | < 1 分钟 | Mac Mini 在线，数据新鲜 |
| 🟡 `●` 亮黄 | 1–5 分钟 | 稍旧，可能没在对话 |
| ⚫ `●` 灰色 | > 5 分钟 | 数据不新鲜，Mac Mini 可能空闲或离线 |
| ⚪ `○` 灰圈 | 未知 | 无时间戳 |

## 前置条件

- 两台 Mac 登录**同一 Apple ID**
- iCloud Drive 已开启：系统设置 → Apple ID → iCloud → iCloud Drive
- Mac Mini：Python 3（macOS 自带有）
- MacBook Pro：安装 MTMR + jq

## 部署步骤

### Mac Mini 端（Claude Code 运行的机器）

#### 1. 放置导出脚本

```bash
cp mac-mini/statusline-export.py ~/.claude/
chmod +x ~/.claude/statusline-export.py
```

#### 2. 配置 Claude Code statusLine

编辑 `~/.claude/settings.json`，添加 statusLine 字段：

```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 ~/.claude/statusline-export.py"
  }
}
```

如果已有其他配置，只需合并 `statusLine` 进去。

纯 Python 实现，无外部依赖。脚本只做两件事：从 stdin 提取 `rate_limits` 写入 iCloud Drive；向 stdout 输出简短用量文字显示在 Claude Code 终端状态栏。

#### 3. 验证

```bash
python3 -c '
import json
print(json.dumps({
  "rate_limits": {
    "five_hour": {"used_percentage": 75, "resets_at": "2026-06-18T20:00:00Z"},
    "seven_day": {"used_percentage": 40, "resets_at": "2026-06-24T08:00:00Z"}
  },
  "model": {"display_name": "Claude"}
}))
' | python3 ~/.claude/statusline-export.py

# 检查生成的文件
cat "$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage/state.json"
```

### MacBook Pro 端（Touch Bar 显示的机器）

#### 1. 安装依赖

```bash
brew install --cask mtmr
brew install jq
```

首次启动 MTMR 需在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权。

#### 2. 放置获取脚本

```bash
cp macbook-pro/touchbar-fetch.sh ~/.claude/
chmod +x ~/.claude/touchbar-fetch.sh
```

#### 3. 配置 MTMR 布局

```bash
mkdir -p "$HOME/Library/Application Support/MTMR"
cp macbook-pro/items.json "$HOME/Library/Application Support/MTMR/items.json"
```

> ⚠️ 如果用户名不是 `luolixie`，需修改 `items.json` 中的 `filePath`。

#### 4. 让 Touch Bar 常驻显示

> 系统设置 → 键盘 → Touch Bar 显示 → 选「展开的控制条」

否则需要按住 Fn 才能看到 MTMR 内容。

#### 5. 验证

```bash
bash ~/.claude/touchbar-fetch.sh
```

应该看到带渐变色进度条的 HUD 风格输出。然后启动 MTMR，Touch Bar 即显示用量。

#### 6. 更新组件

脚本更新后覆盖 `~/.claude/touchbar-fetch.sh` 即可。**无需重启 MTMR** —— 它每 3 秒重新执行脚本，改动自动生效。

## 常见问题

### state.json 没有生成？

1. 确认 Mac Mini 上 Claude Code 的 statusLine 配置正确
2. 运行 `python3 ~/.claude/statusline-export.py` 并粘贴 mock JSON 手动测试

### MacBook Pro 看不到数据？

1. 确认两台 Mac 登录了**同一个 Apple ID**，iCloud Drive 已开启
2. iCloud 同步有 5-30 秒延迟，等待片刻再试
3. 检查 `~/Library/Mobile Documents/com~apple~CloudDocs/claude-usage/` 目录是否存在
4. 确认 MTMR 已授权辅助功能权限

### Touch Bar 显示乱码？

MTMR 只支持标准 16 色 ANSI 码。确保没有安装干扰配色的终端工具。

---

## 卸载

### Mac Mini 端

```bash
# 删除导出脚本
rm ~/.claude/statusline-export.py

# 移除 settings.json 中的 statusLine 配置
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    s = json.load(f)
s.pop('statusLine', None)
with open('$HOME/.claude/settings.json', 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write('\n')
"

# 可选：删除用量数据
rm -rf "$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage"
```

### MacBook Pro 端

```bash
# 删除获取脚本
rm ~/.claude/touchbar-fetch.sh

# 删除 MTMR 配置（恢复默认 Touch Bar）
rm "$HOME/Library/Application Support/MTMR/items.json"

# 可选：卸载 MTMR
brew uninstall --cask mtmr
# 可选：卸载 jq
brew uninstall jq
```

## 文件说明

```
usage-touchbar/
├── README.md
├── mac-mini/
│   ├── statusline-export.py    # Python 导出脚本（无外部依赖）
│   └── settings-patch.json     # settings.json 配置片段
├── macbook-pro/
│   ├── touchbar-fetch.sh       # MTMR 获取+渲染脚本（80级渐变进度条）
│   └── items.json              # MTMR Touch Bar 布局
└── test/
    ├── mock-input.json         # 模拟 statusline JSON
    └── test-pipeline.sh        # 端到端测试脚本
```
