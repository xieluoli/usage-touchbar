#!/usr/bin/env python3
"""Claude Code StatusLine 用量导出脚本（Python 版，无外部依赖）

Claude Code 每个回合结束后通过 statusline hook 调用此脚本，
将完整的 JSON 通过 stdin 传入。
提取 rate_limits 并写入 iCloud Drive，供 MacBook Pro 读取。
"""

import json
import os
import sys
import time
from pathlib import Path

ICLOUD_DIR = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/claude-usage"
STATE_FILE = ICLOUD_DIR / "state.json"


def main():
    ICLOUD_DIR.mkdir(parents=True, exist_ok=True)

    # 读取 stdin 全部 JSON
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("📊 等待用量数据...")
        sys.exit(0)

    rate_limits = data.get("rate_limits", {})
    model_name = data.get("model", {}).get("display_name", "Claude")
    now = int(time.time())

    # 安全提取各字段
    def extract(window):
        if not window or not isinstance(window, dict):
            return None, None
        pct = window.get("used_percentage")
        reset = window.get("resets_at")
        # 确保 percentage 是数字
        if pct is not None:
            try:
                pct = float(pct)
            except (TypeError, ValueError):
                pct = None
        # 将 resets_at 统一为 ISO 8601 字符串
        if isinstance(reset, (int, float)):
            try:
                from datetime import datetime, timezone
                reset = datetime.fromtimestamp(reset, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            except (ValueError, OSError):
                pass
        return pct, reset

    five_pct, five_reset = extract(rate_limits.get("five_hour"))
    seven_pct, seven_reset = extract(rate_limits.get("seven_day"))
    sonnet_pct, sonnet_reset = extract(rate_limits.get("7d_sonnet"))

    # 写入状态文件
    state = {
        "rate_limits": {
            "five_hour": {
                "used_percentage": five_pct,
                "resets_at": five_reset,
            },
            "seven_day": {
                "used_percentage": seven_pct,
                "resets_at": seven_reset,
            },
            "7d_sonnet": {
                "used_percentage": sonnet_pct,
                "resets_at": sonnet_reset,
            },
        },
        "model": model_name,
        "last_updated": now,
    }

    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2))

    # stdout → Claude Code 终端状态栏
    if five_pct is not None:
        s = seven_pct if seven_pct is not None else "?"
        print(f"📊 5h:{five_pct:.0f}% 7d:{s:.0f}%")
    else:
        print("📊 等待用量数据...")


if __name__ == "__main__":
    main()
