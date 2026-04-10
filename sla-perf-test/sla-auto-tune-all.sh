#!/bin/bash
# SLA Auto-tune Performance Test - All Scenarios
#
# 使用方法:
#   ./sla-auto-tune-all.sh <mode> <api_url> <model_path> <tokenizer_path>
#
# 参数:
#   mode          - 测试模式: parallel 或 rate
#   api_url       - API URL
#   model_path    - 模型路径
#   tokenizer_path - Tokenizer 路径

set -e

# 默认参数
OUTPUT=1000
EVALSCOPE=${EVALSCOPE:-/mnt/data/yanlong/evalscope/bin/evalscope}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 检查参数
if [ $# -lt 4 ]; then
    echo "用法: $0 <mode> <api_url> <model_path> <tokenizer_path>"
    echo ""
    echo "参数:"
    echo "  mode          - 测试模式: parallel 或 rate"
    echo "  api_url       - API 地址"
    echo "  model_path    - 模型路径"
    echo "  tokenizer_path - Tokenizer 路径"
    echo ""
    echo "示例:"
    echo "  $0 parallel http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/"
    echo "  $0 rate http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/"
    exit 1
fi

MODE=$1
API_URL=$2
MODEL_PATH=$3
TOKENIZER_PATH=$4

# SLA 配置：输入长度(token) -> p50_ttft p90_ttft p99_ttft upper_bound
# 显示时使用 1k/2k/.../256k 标签，但实际传给 evalscope 的是 token 数。
declare -A SLA_CONFIG
SLA_CONFIG[1000]="2 5 10 512"
SLA_CONFIG[2000]="2 5 10 512"
SLA_CONFIG[4000]="2 5 10 512"
SLA_CONFIG[8000]="2.5 5 12 256"
SLA_CONFIG[16000]="4 8 18 256"
SLA_CONFIG[32000]="4 8 25 128"
SLA_CONFIG[64000]="8 15 35 128"
SLA_CONFIG[128000]="15 35 70 64"
SLA_CONFIG[256000]="30 70 140 32"

# 所有测试场景，单位为 token
SCENARIOS="1000 2000 4000 8000 16000 32000 64000 128000 256000"

# 设置变量名
if [ "$MODE" == "parallel" ]; then
    VARIABLE="parallel"
else
    VARIABLE="rate"
fi

echo "=========================================="
echo "SLA Performance Test - All Scenarios"
echo "=========================================="
echo "Mode:           $MODE"
echo "API URL:       $API_URL"
echo "Model:         $MODEL_PATH"
echo "Tokenizer:     $TOKENIZER_PATH"
echo "Scenarios:     $SCENARIOS"
echo "Output tokens: $OUTPUT"
echo "=========================================="

# 创建结果汇总文件
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${SCRIPT_DIR}/results_${TIMESTAMP}.txt"

echo "SLA Auto-tune Results Summary" > "$RESULTS_FILE"
echo "========================================" >> "$RESULTS_FILE"
echo "Mode: $MODE" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# 执行每个场景
for input_tokens in $SCENARIOS; do
    SLA_PARAMS="${SLA_CONFIG[$input_tokens]}"
    if [ -z "$SLA_PARAMS" ]; then
        echo "警告: 未找到输入 $input_tokens 的 SLA 配置，跳过"
        continue
    fi

    read p50_ttft p90_ttft p99_ttft upper <<< "$SLA_PARAMS"
    if [ "$input_tokens" -ge 1000 ] && [ $((input_tokens % 1000)) -eq 0 ]; then
        display_input="$((input_tokens / 1000))k"
    else
        display_input="$input_tokens"
    fi

    echo ""
    echo "=========================================="
    echo "测试场景: ${display_input} -> ${OUTPUT}"
    echo "SLA: p50_ttft <= ${p50_ttft}s, p90_ttft <= ${p90_ttft}s, p99_ttft <= ${p99_ttft}s"
    echo "=========================================="

    $EVALSCOPE perf \
        --model "$MODEL_PATH" \
        --url "$API_URL" \
        --api openai \
        --api-key EMPTY \
        --dataset random \
        --min-prompt-length "$input_tokens" \
        --max-prompt-length "$input_tokens" \
        --max-tokens "$OUTPUT" \
        --tokenizer-path "$TOKENIZER_PATH" \
        --sla-auto-tune \
        --sla-variable "$VARIABLE" \
        --sla-params "[{\"p50_ttft\": \"<=$p50_ttft\", \"p90_ttft\": \"<=$p90_ttft\", \"p99_ttft\": \"<=$p99_ttft\"}]" \
        --sla-upper-bound "$upper" \
        --parallel 2

    echo ""
    echo "场景 ${display_input} 完成"
done

echo ""
echo "=========================================="
echo "所有测试完成!"
echo "=========================================="
echo "结果汇总: $RESULTS_FILE"