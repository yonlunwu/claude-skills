#!/bin/bash
# SLA Auto-tune Performance Test Script
#
# 使用方法:
#   ./sla-auto-tune.sh <mode> <input_tokens> <api_url> <model_path> <tokenizer_path>
#
# 参数:
#   mode          - 测试模式: parallel 或 rate
#   input_tokens - 输入长度 (tokens)
#   api_url      - API URL
#   model_path   - 模型路径
#   tokenizer_path - Tokenizer 路径

set -e

# 默认参数
OUTPUT=1000
EVALSCOPE=${EVALSCOPE:-/mnt/data/yanlong/evalscope/bin/evalscope}

# 检查参数
if [ $# -lt 5 ]; then
    echo "用法: $0 <mode> <input_tokens> <api_url> <model_path> <tokenizer_path>"
    echo ""
    echo "参数:"
    echo "  mode          - 测试模式: parallel 或 rate"
    echo "  input_tokens - 输入长度 (tokens), 如 1000, 4000, 8000 等"
    echo "  api_url       - API 地址"
    echo "  model_path    - 模型路径"
    echo "  tokenizer_path - Tokenizer 路径"
    echo ""
    echo "示例:"
    echo "  $0 parallel 1000 http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/"
    echo "  $0 rate 4000 http://127.0.0.1:30002/v1/completions /data/models/GLM-5.1-FP8 /data/models/GLM-5.1-FP8/"
    exit 1
fi

MODE=$1
INPUT_TOKENS=$2
API_URL=$3
MODEL_PATH=$4
TOKENIZER_PATH=$5

# 根据输入长度确定 SLA 阈值和 upper bound
get_sla_params() {
    local input=$1
    local p50_ttft p90_ttft upper

    case $input in
        1|1000)
            p50_ttft=2; p90_ttft=5; upper=512 ;;
        2|2000)
            p50_ttft=2; p90_ttft=5; upper=512 ;;
        4|4000)
            p50_ttft=2; p90_ttft=5; upper=512 ;;
        8|8000)
            p50_ttft=2.5; p90_ttft=5; upper=256 ;;
        16|16000)
            p50_ttft=4; p90_ttft=8; upper=256 ;;
        32|32000)
            p50_ttft=4; p90_ttft=8; upper=128 ;;
        64|64000)
            p50_ttft=8; p90_ttft=15; upper=128 ;;
        128|128000)
            p50_ttft=15; p90_ttft=35; upper=64 ;;
        256|256000)
            p50_ttft=30; p90_ttft=70; upper=32 ;;
        *)
            p50_ttft=5; p90_ttft=10; upper=128 ;;
    esac

    echo "${p50_ttft} ${p90_ttft} ${upper}"
}

# 解析 SLA 参数
read p50_ttft p90_ttft upper <<< "$(get_sla_params $INPUT_TOKENS)"

# 设置变量名
if [ "$MODE" == "parallel" ]; then
    VARIABLE="parallel"
else
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
echo "SLA:           p50_ttft <= ${p50_ttft}s, p90_ttft <= ${p90_ttft}s"
echo "Upper bound:   $upper"
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
    --sla-params "[{\"p50_ttft\": \"<=$p50_ttft\", \"p90_ttft\": \"<=$p90_ttft\"}]" \
    --sla-upper-bound "$upper" \
    --parallel 2

echo ""
echo "测试完成: 场景 ${INPUT_TOKENS}-${OUTPUT}, 模式=$MODE"
