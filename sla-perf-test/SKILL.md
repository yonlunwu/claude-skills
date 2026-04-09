# SLA Performance Test Skill

> 执行 SLA 性能测试，通过 evalscope 的 sla-auto-tune 功能自动探测满足 SLA 的最优并发或 QPS。

## 工作流程

1. **询问用户提供信息**（以下信息缺一不可）
2. **根据信息生成脚本**
3. **上传到服务器执行测试**

---

## 1. 询问用户提供的信息

### SLA 目标（必须）
需要用户明确 SLA 指标和阈值。

**支持的指标**：
| 指标 | 说明 |
|------|------|
| `p50_ttft` | P50 首 token 延迟 |
| `p90_ttft` | P90 首 token 延迟 |
| `p99_ttft` | P99 首 token 延迟 |
| `avg_ttft` | 平均首 token 延迟 |
| `p50_tpot` | P50 每输出 token 时间 |
| `p90_tpot` | P90 每输出 token 时间 |
| `p99_tpot` | P99 每输出 token 时间 |
| `avg_tpot` | 平均每输出 token 时间 |

**询问示例**：
> SLA 目标是什么？（请提供指标和阈值，如 p50_ttft <= 2s, p90_ttft <= 5s）

### 测试场景（必须）
需要用户明确：
- 输入长度（如 1k, 4k, 8k, 16k, 32k, 64k, 128k）
- 输出长度（默认 1k）
- 测试模式（parallel 或 rate）

**询问示例**：
> 输入长度是多少？（如 1k, 4k, 8k, 16k, 32k, 64k, 128k）

### Evalscope 环境（必须）
需要用户提供：
- evalscope 路径（如 `/mnt/data/yanlong/evalscope/bin/evalscope`）
- API URL（如 `http://127.0.0.1:30002/v1/completions`）
- API Key（如 `EMPTY`）
- 模型路径（如 `/data/models/GLM-5.1-FP8`）
- Tokenizer 路径（如 `/data/models/GLM-5.1-FP8/`）

**询问示例**：
> evalscope 路径在哪里？
> API URL 和 Key 是什么？
> 模型路径和 Tokenizer 路径是什么？

---

## 2. 生成的脚本模板

根据用户提供的 SLA 条件，生成对应脚本：

```bash
#!/bin/bash
# SLA Auto-tune Performance Test Script
#
# 使用方法:
#   ./sla-auto-tune.sh <mode> <input_tokens> <api_url> <model_path> <tokenizer_path>

set -e

EVALSCOPE=${EVALSCOPE:-<evalscope_path>}
MODEL_PATH=<model_path>
TOKENIZER_PATH=<tokenizer_path>
API_URL=<api_url>
API_KEY=<api_key>
INPUT_TOKENS=<input_tokens>
OUTPUT_TOKENS=<output_tokens>
MODE=<parallel|rate>

# SLA 参数（用户指定）
SLA_PARAMS='[{"<metric1>": "<=<value1>", "<metric2>": "<=<value2>"}]'
UPPER_BOUND=<upper_bound>

$EVALSCOPE perf \
    --model "$MODEL_PATH" \
    --url "$API_URL" \
    --api openai \
    --api-key "$API_KEY" \
    --dataset random \
    --min-prompt-length "$INPUT_TOKENS" \
    --max-prompt-length "$INPUT_TOKENS" \
    --max-tokens "$OUTPUT_TOKENS" \
    --tokenizer-path "$TOKENIZER_PATH" \
    --sla-auto-tune \
    --sla-variable "$MODE" \
    --sla-params "$SLA_PARAMS" \
    --sla-upper-bound "$UPPER_BOUND" \
    --parallel 2
```

---

## 3. 上传到服务器并执行

将生成的脚本上传到用户指定服务器的脚本目录下，然后执行。

---

## 示例对话

```
用户: 我需要测试 GLM-5.1-FP8 模型
用户: SLA: p50_ttft <= 2s, p90_ttft <= 5s
用户: 输入: 8k
用户: evalscope: /mnt/data/yanlong/evalscope/bin/evalscope
用户: API: http://127.0.0.1:30002/v1/completions, key: EMPTY
用户: 模型: /data/models/GLM-5.1-FP8

Agent: 明白了，我为您生成测试脚本...
Agent: 脚本已上传到 /mnt/data/yanlong/scripts/sla-auto-tune/sla-auto-tune.sh
Agent: 请确认是否需要立即执行测试
```

---

---

## Base CLI 模板

### Parallel 模式 (并发控制)

```bash
evalscope perf \
    --model /data/models/GLM-5.1-FP8 \
    --url http://127.0.0.1:30002/v1/completions \
    --api openai \
    --api-key EMPTY \
    --dataset random \
    --min-prompt-length 8000 \
    --max-prompt-length 8000 \
    --max-tokens 1000 \
    --tokenizer-path /data/models/GLM-5.1-FP8/ \
    --sla-auto-tune \
    --sla-variable parallel \
    --sla-params "[{\"p50_ttft\": \"<=2.5\", \"p90_ttft\": \"<=5\"}]" \
    --sla-upper-bound 256 \
    --parallel 2
```

### Rate 模式 (QPS 控制)

```bash
evalscope perf \
    --model /data/models/GLM-5.1-FP8 \
    --url http://127.0.0.1:30002/v1/completions \
    --api openai \
    --api-key EMPTY \
    --dataset random \
    --min-prompt-length 8000 \
    --max-prompt-length 8000 \
    --max-tokens 1000 \
    --tokenizer-path /data/models/GLM-5.1-FP8/ \
    --sla-auto-tune \
    --sla-variable rate \
    --sla-params "[{\"p50_ttft\": \"<=2.5\", \"p90_ttft\": \"<=5\"}]" \
    --sla-upper-bound 128 \
    --parallel 2
```

---

## 可用脚本

### 单场景脚本 (sla-auto-tune.sh)
测试单个输入长度的 SLA 性能，自动根据输入长度调整 SLA 阈值：

| 输入长度 | p50_ttft | p90_ttft | upper_bound |
|---------|----------|----------|-------------|
| 1k-4k   | 2s       | 5s       | 512         |
| 8k      | 2.5s     | 5s       | 256         |
| 16k     | 4s       | 8s       | 256         |
| 32k     | 4s       | 8s       | 128         |
| 64k     | 8s       | 15s      | 128         |
| 128k    | 15s      | 35s      | 64          |
| 256k    | 30s      | 70s      | 32          |

```bash
./sla-auto-tune.sh <mode> <input_tokens> <api_url> <model_path> <tokenizer_path>
# 示例: ./sla-auto-tune.sh parallel 8000 http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/
```

### 全量测试脚本 (sla-auto-tune-all.sh)
自动测试所有场景 (1k, 2k, 4k, 8k, 16k, 32k, 64k, 128k, 256k)，生成结果汇总文件：

```bash
./sla-auto-tune-all.sh <mode> <api_url> <model_path> <tokenizer_path>
# 示例: ./sla-auto-tune-all.sh parallel http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/
```

---

## 注意事项

1. **sla-params 格式**：
   - 必须使用 JSON 格式：`[{"<metric>": "<=<value>"}]`
   - 多个指标用逗号分隔：`[{"p50_ttft": "<=2", "p90_ttft": "<=5"}]`
   - 支持 AND 逻辑（同一 group 内所有指标都必须满足）

2. **sla-auto-tune 会自动**：
   - 测试不同并发/rate 值
   - 二分搜索找到满足 SLA 的最大并发/rate
   - 输出满足 SLA 的最大 QPS 或并发数

3. **成功标准**：成功率必须 100%，否则 SLA 视为不满足
