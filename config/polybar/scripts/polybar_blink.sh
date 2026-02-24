#!/bin/bash

STATE_FILE="$HOME/.cache/blink_state.json"

# 状態ファイルが存在しない、または古い場合
if [ ! -f "$STATE_FILE" ]; then
  echo " --"
  exit 0
fi

# check timestamp freshness (disabled if > 30s ago)
LAST_UPDATE=$(jq -r '.timestamp // 0' "$STATE_FILE" | cut -d. -f1)
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_UPDATE))

if [ "$TIME_DIFF" -gt 15 ]; then
  echo "󰈉 --"
  exit 0
fi

# parse JSON
BLINK_INTERVAL=$(jq -r '.interval // 0' "$STATE_FILE")
EYES_OPEN=$(jq -r '.eyes_open' "$STATE_FILE")

if [ "$EYES_OPEN" = "true" ]; then
  ICON="󰈈"
else
  ICON="-"
fi

echo "${ICON} ${BLINK_INTERVAL}s"

# CURRENT_TIME=$(date +%s)
# FILE_TIME=$(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)
# TIME_DIFF=$((CURRENT_TIME - FILE_TIME))
#
# if [ $TIME_DIFF -gt 5 ]; then
#   echo " offline"
#   exit 0
# fi
#
# # JSONから情報を取得
# BLINK_RATE=$(jq -r '.blink_rate_1min' "$STATE_FILE" 2>/dev/null || echo "0")
# TOTAL=$(jq -r '.total_blinks' "$STATE_FILE" 2>/dev/null || echo "0")
# IS_BLINKING=$(jq -r '.is_blinking' "$STATE_FILE" 2>/dev/null || echo "false")
# FACE_DETECTED=$(jq -r '.face_detected' "$STATE_FILE" 2>/dev/null || echo "false")
#
# # アイコンの選択
# if [ "$FACE_DETECTED" != "true" ]; then
#   ICON=""
# elif [ "$IS_BLINKING" = "true" ]; then
#   ICON=""
# else
#   ICON=""
# fi
#
# # まばたきレートに基づいて色を変える（オプション）
# if [ "$BLINK_RATE" -lt 10 ]; then
#   COLOR="%{F#FF6B6B}" # 赤: まばたきが少ない
# elif [ "$BLINK_RATE" -lt 15 ]; then
#   COLOR="%{F#FFA500}" # オレンジ: やや少ない
# else
#   COLOR="%{F#4CAF50}" # 緑: 正常
# fi
#
# # 出力
# echo "${COLOR}${ICON} ${BLINK_RATE}/min (${TOTAL})%{F-}"
