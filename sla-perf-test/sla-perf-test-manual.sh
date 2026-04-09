#!/bin/bash
# SLA Performance Test Skill - 手动固定并发版
#
# 使用方法:
#   ./sla-perf-test-manual.sh --mode parallel \
#                              --scenarios <scenarios> \
#                              --api-url <url> \
#                              --api-key <key> \
#                              --evalscope <path> \
#                              --model <path> \
#                              --tokenizer <path> \
#                              [--tpot <ms>] \
#                              [--ttft <s>]
#
# 或者使用交互模式（不带参数运行）:
#   ./sla-perf-test-manual.sh

set -e

# 默认值
DEFAULT_TPOT=50
DEFAULT_TTFT=5
DEFAULT_OUTPUT=1000
DEFAULT_EVALSCOPE=/mnt/data/yanlong/evalscope/bin/evalscope

# 并发级别配置（短输入用细粒度，长输入用粗粒度）
declare -A PARALLEL_LEVELS
PARALLEL_LEVELS["1k"]="1,20,40,60,80,100,120,140,160,180,200,220,240,260,280,300,320,340,360,380,400,420,440,460,480,512"
PARALLEL_LEVELS["4k"]="1,20,40,60,80,100,120,140,160,180,200,220,240,260,280,300,320,340,360,380,400,420,440,460,480,512"
PARALLEL_LEVELS["8k"]="1,32,64,96,128,160,192,224,256"
PARALLEL_LEVELS["16k"]="1,32,64,96,128,160,192,224,256"
PARALLEL_LEVELS["32k"]="1,32,64,96,128"
PARALLEL_LEVELS["64k"]="1,32,64,96,128"
PARALLEL_LEVELS["128k"]="1,16"

# 交互式询问函数
ask_parameters() {
    echo "=========================================="
    echo "SLA 性能测试 - 交互式参数输入 (手动并发版)"
    echo "=========================================="
    echo ""

    # 1. SLA 目标
    echo "1. SLA 目标是什么？"
    echo "   默认: TPOT ≤ ${DEFAULT_TPOT}ms, TTFT ≤ ${DEFAULT_TTFT}s"
    read -p "   请输入 TPOT 阈值 (ms): " TPOT_INPUT
    read -p "   请输入 TTFT 阈值 (s): " TTFT_INPUT
    TPOT=${TPOT_INPUT:-$DEFAULT_TPOT}
    TTFT=${TTFT_INPUT:-$DEFAULT_TTFT}
    echo ""

    # 2. 输入输出场景
    echo "2. 输入输出场景是什么？"
    echo "   格式: <input_tokens>-<output_tokens>"
    echo "   示例: 1000-1000, 4000-1000, 8000-1000"
    echo "   可选场景: 1k, 4k, 8k, 16k, 32k, 64k, 128k (后缀 k 表示 1000)"
    read -p "   请输入场景 (多个用逗号分隔，默认全部): " SCENARIOS_INPUT
    SCENARIOS=${SCENARIOS_INPUT:-"1k,4k,8k,16k,32k,64k,128k"}
    echo ""

    # 3. 测试模式
    echo "3. 测试模式是什么？"
    echo "   parallel: 手动设置并发级别，逐个测试"
    echo "   rate: 找满足 SLA 的最大 QPS"
    read -p "   请输入模式 (parallel/rate): " MODE_INPUT
    MODE=${MODE_INPUT:-parallel}
    echo ""

    # 4. Evalscope 路径
    echo "4. evalscope 路径在哪里？"
    echo "   默认: $DEFAULT_EVALSCOPE"
    read -p "   请输入 evalscope 路径: " EVALSCOPE_INPUT
    EVALSCOPE_PATH=${EVALSCOPE_INPUT:-$DEFAULT_EVALSCOPE}
    echo ""

    # 5. 测试 API
    echo "5. 测试 API URL 和 Key 是什么？"
    read -p "   请输入 API URL: " API_URL_INPUT
    read -p "   请输入 API Key (EMPTY 或具体 key): " API_KEY_INPUT
    API_URL=${API_URL_INPUT}
    API_KEY=${API_KEY_INPUT:-EMPTY}
    echo ""

    # 6. 模型路径
    echo "6. 模型路径是什么？"
    read -p "   请输入模型路径: " MODEL_PATH_INPUT
    MODEL_PATH=${MODEL_PATH_INPUT}
    echo ""

    # 7. Tokenizer 路径
    echo "7. Tokenizer 路径是什么？"
    read -p "   请输入 Tokenizer 路径: " TOKENIZER_INPUT
    TOKENIZER_PATH=${TOKENIZER_INPUT}
    echo ""
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                MODE="$2"
                shift 2
                ;;
            --scenarios)
                SCENARIOS="$2"
                shift 2
                ;;
            --api-url)
                API_URL="$2"
                shift 2
                ;;
            --api-key)
                API_KEY="$2"
                shift 2
                ;;
            --evalscope)
                EVALSCOPE_PATH="$2"
                shift 2
                ;;
            --model)
                MODEL_PATH="$2"
                shift 2
                ;;
            --tokenizer)
                TOKENIZER_PATH="$2"
                shift 2
                ;;
            --tpot)
                TPOT="$2"
                shift 2
                ;;
            --ttft)
                TTFT="$2"
                shift 2
                ;;
            *)
                echo "未知参数: $1"
                exit 1
                ;;
        esac
    done
}

# 检查必需参数
check_parameters() {
    local missing=""

    [[ -z "$MODE" ]] && missing="$missing MODE"
    [[ -z "$SCENARIOS" ]] && missing="$missing SCENARIOS"
    [[ -z "$API_URL" ]] && missing="$missing API_URL"
    [[ -z "$MODEL_PATH" ]] && missing="$missing MODEL_PATH"
    [[ -z "$TOKENIZER_PATH" ]] && missing="$missing TOKENIZER_PATH"

    if [[ -n "$missing" ]]; then
        echo "错误: 缺少必需参数:$missing"
        echo "使用 --help 查看帮助"
        exit 1
    fi
}

# 转换场景名称到实际 tokens
resolve_scenario() {
    local scenario=$1
    case $scenario in
        1k) echo "1000" ;;
        4k) echo "4000" ;;
        8k) echo "8000" ;;
        16k) echo "16000" ;;
        32k) echo "32000" ;;
        64k) echo "64000" ;;
        128k) echo "128000" ;;
        *) echo "$scenario" ;;
    esac
}

# 获取并发级别列表
get_parallel_list() {
    local input_k=$1
    echo "${PARALLEL_LEVELS[$input_k]}"
}

# 执行单个测试
run_test() {
    local input=$1
    local output=$2
    local parallel=$3

    echo "----------------------------------------"
    echo "测试: ${input}-${output}, 并发=$parallel"
    echo "SLA: TPOT ≤ ${TPOT}ms, TTFT ≤ ${TTFT}s"
    echo "----------------------------------------"

    # 使用 number=4 避免 tokenizer 并发问题
    $EVALSCOPE_PATH perf \
        --model "$MODEL_PATH" \
        --url "$API_URL" \
        --api openai \
        --api-key "$API_KEY" \
        --dataset random \
        --min-prompt-length "$input" \
        --max-prompt-length "$input" \
        --max-tokens "$output" \
        --tokenizer-path "$TOKENIZER_PATH" \
        --parallel "$parallel" \
        --number 4 \
        --seed "$((RANDOM % 20000 + 1))"

    echo ""
}

# 显示帮助
show_help() {
    echo "SLA 性能测试脚本 (手动并发版)"
    echo ""
    echo "使用方法:"
    echo "  $0 --mode parallel \\"
    echo "        --scenarios <scenarios> \\"
    echo "        --api-url <url> \\"
    echo "        --api-key <key> \\"
    echo "        --model <path> \\"
    echo "        --tokenizer <path> \\"
    echo "        [--tpot <ms>] \\"
    echo "        [--ttft <s>]"
    echo ""
    echo "参数说明:"
    echo "  --scenarios   测试场景, 支持简写或实际 tokens"
    echo "                简写: 1k,4k,8k,16k,32k,64k,128k"
    echo "                或实际值: 1000-1000,4000-1000"
    echo "                默认: 1k,4k,8k,16k,32k,64k,128k (输出固定 1k)"
    echo "  --api-url     API URL"
    echo "  --api-key     API Key (默认: EMPTY)"
    echo "  --model       模型路径"
    echo "  --tokenizer   Tokenizer 路径"
    echo "  --tpot        TPOT 阈值 ms (默认: $DEFAULT_TPOT)"
    echo "  --ttft        TTFT 阈值 s (默认: $DEFAULT_TTFT)"
    echo ""
    echo "示例:"
    echo "  $0 --mode parallel \\"
    echo "     --scenarios 1k,4k,8k \\"
    echo "     --api-url http://127.0.0.1:30002/v1/completions \\"
    echo "     --api-key EMPTY \\"
    echo "     --model /data/models/GLM-5.1-FP8 \\"
    echo "     --tokenizer /data/models/GLM-5.1-FP8/"
}

# 主函数
main() {
    # 如果没有参数, 进入交互模式
    if [[ $# -eq 0 ]]; then
        ask_parameters
    else
        parse_args "$@"
    fi

    check_parameters

    # 设置默认值
    TPOT=${TPOT:-$DEFAULT_TPOT}
    TTFT=${TTFT:-$DEFAULT_TTFT}
    OUTPUT_TOKENS=${OUTPUT_TOKENS:-$DEFAULT_OUTPUT}
    EVALSCOPE_PATH=${EVALSCOPE_PATH:-$DEFAULT_EVALSCOPE}

    echo ""
    echo "=========================================="
    echo "开始 SLA 性能测试 (手动并发版)"
    echo "=========================================="
    echo "Mode:           $MODE"
    echo "TPOT:           ≤ ${TPOT}ms"
    echo "TTFT:           ≤ ${TTFT}s"
    echo "API URL:       $API_URL"
    echo "Model:         $MODEL_PATH"
    echo "Tokenizer:     $TOKENIZER_PATH"
    echo "Evalscope:     $EVALSCOPE_PATH"
    echo "=========================================="
    echo ""

    # 解析并执行每个场景
    IFS=',' read -ra SCENARIO_ARRAY <<< "$SCENARIOS"
    for scenario in "${SCENARIO_ARRAY[@]}"; do
        # 解析场景名称
        local input_k=$(echo "$scenario" | tr -d ' ')
        local input_tokens=$(resolve_scenario "$input_k")
        local parallel_list=$(get_parallel_list "$input_k")

        if [[ -z "$parallel_list" ]]; then
            echo "警告: 未知场景 '$scenario', 跳过"
            continue
        fi

        echo ">>> 场景: ${input_tokens}-${OUTPUT_TOKENS}"
        echo "    并发级别: $parallel_list"
        echo ""

        # 逐个测试并发级别
        IFS=',' read -ra PARALLEL_ARRAY <<< "$parallel_list"
        local max_satisfied_parallel=0
        local last_result=""

        for parallel in "${PARALLEL_ARRAY[@]}"; do
            # 执行测试并捕获输出
            last_result=$($EVALSCOPE_PATH perf \
                --model "$MODEL_PATH" \
                --url "$API_URL" \
                --api openai \
                --api-key "$API_KEY" \
                --dataset random \
                --min-prompt-length "$input_tokens" \
                --max-prompt-length "$input_tokens" \
                --max-tokens "$OUTPUT_TOKENS" \
                --tokenizer-path "$TOKENIZER_PATH" \
                --parallel "$parallel" \
                --number 4 \
                --seed "$((RANDOM % 20000 + 1))" 2>&1)

            # 检查输出
            echo "$last_result"

            # 提取关键指标
            local avg_tpot=$(echo "$last_result" | grep -o '"Average time per output token (s)":[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$' | head -1)
            local avg_ttft=$(echo "$last_result" | grep -o '"Average time to first token (s)":[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$' | head -1)
            local success_rate=$(echo "$last_result" | grep -o '"Succeed requests":[[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1)

            if [[ -z "$avg_tpot" ]] || [[ -z "$avg_ttft" ]]; then
                echo "    [ERROR] 无法解析测试结果"
                break
            fi

            # 检查 SLA 是否满足
            local tpot_sec=$(echo "scale=4; $TPOT/1000" | bc)
            local tpot_pass=$(echo "$avg_tpot <= $tpot_sec" | bc)
            local ttft_pass=$(echo "$avg_ttft <= $TTFT" | bc)

            echo "    [RESULT] avg_tpot=${avg_tpot}s, avg_ttft=${avg_ttft}s, success=${success_rate}"

            if [[ "$tpot_pass" -eq 1 ]] && [[ "$ttft_pass" -eq 1 ]] && [[ "$success_rate" -eq 4 ]]; then
                echo "    [PASS] SLA 满足"
                max_satisfied_parallel=$parallel
            else
                echo "    [FAIL] SLA 不满足，停止增加并发"
                break
            fi
        done

        echo ">>> 场景 ${input_tokens}-${OUTPUT_TOKENS} 结果: 最大满足 SLA 的并发 = $max_satisfied_parallel"
        echo ""
    done

    echo "=========================================="
    echo "所有测试完成!"
    echo "=========================================="
}

main "$@"
