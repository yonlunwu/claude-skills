#!/bin/bash
# SLA Auto-tune Performance Test Script
#
# 使用方法:
#   ./sla-perf-test.sh <mode> <input_tokens> <api_url> <model_path> <tokenizer_path>
#
# 参数:
#   mode          - 测试模式: parallel 或 rate
#   input_tokens  - 输入长度 (tokens)
#   api_url       - API URL
#   model_path    - 模型路径
#   tokenizer_path - Tokenizer 路径

set -e

# SLA 参数
TPOT=50  # ms
TTFT=5   # s
OUTPUT=1000

# 检查参数
if [ $# -lt 5 ]; then
    echo "用法: $0 <mode> <input_tokens> <api_url> <model_path> <tokenizer_path>"
    echo ""
    echo "参数:"
    echo "  mode          - 测试模式: parallel 或 rate"
    echo "  input_tokens  - 输入长度 (tokens), 如 1000, 4000, 8000 等"
    echo "  api_url       - API 地址"
    echo "  model_path    - 模型路径"
    echo "  tokenizer_path - Tokenizer 路径"
    echo ""
    echo "示例:"
    echo "  $0 parallel 1000 http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/"
    echo "  $0 rate 1000 http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/"
    exit 1
fi

MODE=$1
INPUT_TOKENS=$2
API_URL=$3
MODEL_PATH=$4
TOKENIZER_PATH=$5
EVALSCOPE=${EVALSCOPE:-/mnt/data/yanlong/evalscope/bin/evalscope}

# SLA 上下限配置
if [ "$MODE" == "parallel" ]; then
    # 并发模式: 根据输入长度设置不同的上限
    if [ "$INPUT_TOKENS" -le 1000 ]; then
        UPPER_BOUND=512
    elif [ "$INPUT_TOKENS" -le 4000 ]; then
        UPPER_BOUND=512
    elif [ "$INPUT_TOKENS" -le 8000 ]; then
        UPPER_BOUND=256
    elif [ "$INPUT_TOKENS" -le 16000 ]; then
        UPPER_BOUND=256
    elif [ "$INPUT_TOKENS" -le 32000 ]; then
        UPPER_BOUND=128
    elif [ "$INPUT_TOKENS" -le 64000 ]; then
        UPPER_BOUND=128
    else
        UPPER_BOUND=64
    fi
    VARIABLE="parallel"
else
    # Rate 模式
    if [ "$INPUT_TOKENS" -le 1000 ]; then
        UPPER_BOUND=512
    elif [ "$INPUT_TOKENS" -le 4000 ]; then
        UPPER_BOUND=256
    elif [ "$INPUT_TOKENS" -le 8000 ]; then
        UPPER_BOUND=128
    else
        UPPER_BOUND=64
    fi
    VARIABLE="rate"
fi

echo "=========================================="
echo "SLA Performance Test"
echo "=========================================="
echo "Mode:           $MODE"
echo "Input tokens:   $INPUT_TOKENS"
echo "Output tokens: $OUTPUT"
echo "API URL:       $API_URL"
echo "Model:         $MODEL_PATH"
echo "Tokenizer:     $TOKENIZER_PATH"
echo "SLA:           TPOT <= ${TPOT}ms, TTFT <= ${TTFT}s"
echo "Upper bound:   $UPPER_BOUND"
echo "=========================================="

# 执行测试
$EVALSCOPE perf \
    --model "$MODEL_PATH" \
    --url "$API_URL" \
    --api openai \
    --api-key EMPTY \
    --dataset random \
    --min-prompt-length "$INPUT_TOKENS" \
    --max-prompt-length "$INPUT_TOKENS" \
    --max-tokens "$OUTPUT" \
    --tokenizer-path "$TOKENIZER_PATH" \
    --sla-auto-tune \
    --sla-variable "$VARIABLE" \
    --sla-params "[{\"avg_tpot\": \"<=$((TPOT/1000))\", \"avg_ttft\": \"<=$TTFT\"}]" \
    --sla-upper-bound "$UPPER_BOUND" \
    --parallel 2

echo ""
echo "测试完成: 场景 ${INPUT_TOKENS}-${OUTPUT}, 模式=$MODE"
