# 补丁：增加 p50/p90 支持到 get_metric_values
# 找到 /mnt/data/yanlong/evalscope/lib/python3.12/site-packages/evalscope/perf/sla/sla_run.py
# 修改 get_metric_values 函数

--- a/sla_run.py
+++ b/sla_run.py
@@ -55,20 +55,32 @@ def get_metric_values(results: Dict[str, Any]) -> Dict[str, float]:
     values['p99_latency'] = get_p99(PercentileMetrics.LATENCY)
     values['p99_ttft'] = get_p99(PercentileMetrics.TTFT)
     values['p99_tpot'] = get_p99(PercentileMetrics.TPOT)

+    # Add p50 and p90 support
+    if percentiles_data:
+        p_idx = percentiles_data.get(PercentileMetrics.PERCENTILES, [])
+        try:
+            p50_idx = p_idx.index('50%')
+            p90_idx = p_idx.index('90%')
+
+            def get_p(key, idx):
+                lst = percentiles_data.get(key, [])
+                return lst[idx] if lst and len(lst) > idx and isinstance(lst[idx], (int, float)) else 0
+
+            values['p50_ttft'] = get_p(PercentileMetrics.TTFT, p50_idx)
+            values['p90_ttft'] = get_p(PercentileMetrics.TTFT, p90_idx)
+            values['p50_tpot'] = get_p(PercentileMetrics.TPOT, p50_idx)
+            values['p90_tpot'] = get_p(PercentileMetrics.TPOT, p90_idx)
+        except ValueError:
+            pass
+
     return values
