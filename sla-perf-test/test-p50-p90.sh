#!/bin/bash
# 测试 p50/p90 SLA 参数
/mnt/data/yanlong/evalscope/bin/evalscope perf \
  --model /data/models/GLM-5.1-FP8 \
  --url http://127.0.0.1:30002/v1/completions \
  --api openai \
  --api-key EMPTY \
  --dataset random \
  --max-tokens 1024 \
  --sla-auto-tune \
  --sla-variable parallel \
  --sla-params '[{"p50_ttft": "<=2", "p90_ttft": "<=5"}]' \
  --parallel 2 \
  --sla-upper-bound 64 \
  --tokenizer-path /data/models/GLM-5.1-FP8 \
  --min-prompt-length 60000 \
  --max-prompt-length 60001
