#!/usr/bin/env python3
with open('/mnt/data/yanlong/evalscope/lib/python3.12/site-packages/evalscope/perf/sla/sla_run.py', 'r') as f:
    lines = f.readlines()

# Fix lines 163 and 164
if len(lines) > 164:
    lines[162] = "            logger.info('SLA Auto-tune Summary:\\n' + tabulate(self.sla_results_table, headers='keys', tablefmt='grid'))\n"
    del lines[163]  # Remove line 164 since we merged it

with open('/mnt/data/yanlong/evalscope/lib/python3.12/site-packages/evalscope/perf/sla/sla_run.py', 'w') as f:
    f.writelines(lines)

print('Fixed lines 163-164')
