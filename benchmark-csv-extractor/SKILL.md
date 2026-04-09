---
name: benchmark-csv-extractor
description: 从 benchmark 日志文件中提取 Benchmarking summary 数据并转换为 CSV 格式
---

# Benchmark 日志转 CSV 工具

## 触发场景

用户说"提取这份日志"、"把这个 log 转 csv"、"提取 benchmark 数据"等时使用。

---

## 核心功能

从包含 `Benchmarking summary:` 的日志文件中提取所有指标数据并保存为 CSV。

---

## 字段列表（共 15 个字段，按顺序）

1. Time taken for tests (s)
2. Number of concurrency
3. Request rate (req/s)
4. Total requests
5. Succeed requests
6. Failed requests
7. Output token throughput (tok/s)
8. Total token throughput (tok/s)
9. Request throughput (req/s)
10. Average latency (s)
11. Average time to first token (s)
12. Average time per output token (s)
13. Average inter-token latency (s)
14. Average input tokens per request
15. Average output tokens per request

---

## 工作流程

### Step 1: 确认输入文件

确认用户提供的日志文件路径。

### Step 2: 提取数据

使用 Python 脚本提取数据，确保按 Key 名称精确匹配：

```python
import re

with open('用户提供的日志文件路径', 'r') as f:
    content = f.read()

# Find all benchmarking sections
sections = re.split(r'Benchmarking summary:', content)[1:]

header = "Time taken for tests (s),Number of concurrency,Request rate (req/s),Total requests,Succeed requests,Failed requests,Output token throughput (tok/s),Total token throughput (tok/s),Request throughput (req/s),Average latency (s),Average time to first token (s),Average time per output token (s),Average inter-token latency (s),Average input tokens per request,Average output tokens per request"

results = []
for section in sections:
    lines = section.strip().split('\n')
    data = {}
    for line in lines:
        match = re.search(r'\|\s*(.+?)\s*\|\s*(.+?)\s*\|', line)
        if match:
            key = match.group(1).strip()
            value = match.group(2).strip()
            data[key] = value

    if len(data) >= 15:
        row = [
            data.get('Time taken for tests (s)', ''),
            data.get('Number of concurrency', ''),
            data.get('Request rate (req/s)', ''),
            data.get('Total requests', ''),
            data.get('Succeed requests', ''),
            data.get('Failed requests', ''),
            data.get('Output token throughput (tok/s)', ''),
            data.get('Total token throughput (tok/s)', ''),
            data.get('Request throughput (req/s)', ''),
            data.get('Average latency (s)', ''),
            data.get('Average time to first token (s)', ''),
            data.get('Average time per output token (s)', ''),
            data.get('Average inter-token latency (s)', ''),
            data.get('Average input tokens per request', ''),
            data.get('Average output tokens per request', ''),
        ]
        if all(row):
            results.append(','.join(row))

with open('输出的CSV文件路径', 'w') as f:
    f.write(header + '\n')
    f.write('\n'.join(results))

print(f"Saved {len(results)} rows to CSV")
```

### Step 3: 命名 CSV 文件

- CSV 文件名应与输入日志文件名匹配
- 例如：`1p1d_log_1.log` → `1p1d_log_1.csv`
- 路径与原始日志保持一致

### Step 4: 验证正确性（必做）

**必须验证至少一行数据与原始日志一致！**

验证方法：
```bash
# 找到最后一个 benchmark 的行号
grep -n "Benchmarking summary:" 日志文件路径 | tail -1

# 提取该行后续的 15 行数据
sed -n '行号,行号+20p' 日志文件路径 | grep "| " | grep -v "Key\|---"
```

对比提取的数据与 CSV 中的最后一行是否一致。

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|:---|:---|:---|
| 字段提取错位 | 未按 Key 名称匹配 | 必须使用 Key-Value 匹配方式提取 |
| 数据丢失 | 正则表达式未匹配到所有行 | 检查日志格式是否一致 |
| 字段数不足 | 日志中缺少某些字段 | 确保有完整的 15 个字段 |

---

## 验证清单

- [ ] CSV 文件已生成
- [ ] 字段顺序与原始日志一致
- [ ] 至少验证了一行数据与原始日志匹配
- [ ] CSV 命名与日志文件匹配