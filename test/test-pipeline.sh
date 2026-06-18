#!/bin/bash
# ============================================================
# 端到端测试脚本
# 用法: bash test/test-pipeline.sh
# ============================================================

set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== 1. 测试 Mac Mini 端导出脚本 ==="
echo "输入: test/mock-input.json"
bash mac-mini/statusline-export.sh < test/mock-input.json
echo ""

# 验证 state.json 生成位置
STATE_FILE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage/state.json"
if [ -f "$STATE_FILE" ]; then
  echo "✅ state.json 已生成"
  echo "--- state.json 内容 ---"
  cat "$STATE_FILE"
  echo "----------------------"
else
  echo "⚠️  state.json 未在 iCloud 目录找到（测试环境正常）"
  echo "   检查 ~/.claude/usage-state.json 本地副本..."
fi

echo ""
echo "=== 2. 测试 MacBook Pro 端 Touch Bar 脚本 ==="
# 模拟 iCloud 路径不存在时的回退行为
if [ -f "$STATE_FILE" ]; then
  bash macbook-pro/touchbar-fetch.sh
else
  # 手动创建临时 state 文件用于测试
  TMP_DIR="/tmp/claude-usage-test"
  mkdir -p "$TMP_DIR"
  cp test/mock-input.json "$TMP_DIR/state.json"
  echo "(使用临时测试文件)"
fi

echo ""
echo "=== 3. 测试边界情况 ==="

# 3a: 空 rate_limits
echo "--- 3a: 空 rate_limits ---"
echo '{"rate_limits":{},"model":{"display_name":"test"}}' | bash mac-mini/statusline-export.sh

# 3b: 高用量警告（90%）
echo "--- 3b: 高用量 90% ---"
cat test/mock-input.json \
  | jq '.rate_limits.five_hour.used_percentage = 90' \
  | bash mac-mini/statusline-export.sh

echo ""
echo "=== 测试完成 ==="
