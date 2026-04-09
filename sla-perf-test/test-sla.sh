#!/bin/bash
# SLA Auto-tune 测试脚本 (苛刻条件快速测试)

echo "=========================================="
echo "测试1: Parallel 模式 (苛刻 SLA)"
echo "=========================================="

/mnt/data/yanlong/evalscope/bin/evalscope perf \
  --model /data/models/GLM-5.1-FP8 \
  --url http://127.0.0.1:30002/v1/completions \
  --api openai \
  --api-key EMPTY \
  --dataset random \
  --max-tokens 1000 \
  --sla-auto-tune \
  --sla-variable parallel \
  --sla-params '[{"avg_tpot": "<=0.01", "avg_ttft": "<=0.5"}]' \
  --parallel 1 \
  --sla-upper-bound 20 \
  --tokenizer-path /data/models/GLM-5.1-FP8 \
  --min-prompt-length 1000 \
  --max-prompt-length 1000

echo ""
echo "=========================================="
echo "测试2: Rate 模式 (苛刻 SLA)"
echo "=========================================="

/mnt/data/yanlong/evalscope/bin/evalscope perf \
  --model /data/models/GLM-5.1-FP8 \
  --url http://127.0.0.1:30002/v1/completions \
  --api openai \
  --api-key EMPTY \
  --dataset random \
  --max-tokens 1000 \
  --sla-auto-tune \
  --sla-variable rate \
  --sla-params '[{"avg_tpot": "<=0.01", "avg_ttft": "<=0.5"}]' \
  --parallel 1 \
  --sla-upper-bound 20 \
  --tokenizer-path /data/models/GLM-5.1-FP8 \
  --min-prompt-length 1000 \
  --max-prompt-length 1000

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
