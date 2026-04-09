---
name: pdf-to-qujing-style
description: 将 PDF/Word 文档转换为趋境风格。仅修改格式，不做任何内容变更。
---

# PDF/Word 转趋境风格报告

## 触发场景

用户说"把这个 PDF 转为趋境风格"、"将 PDF 改为趋境风格"、"把 Word 转为趋境风格"等时使用。

## 核心原则

**仅修改格式为趋境风格，不做任何内容变更！不做任何内容变更！不做任何内容变更！**

---

## 工作流程

### Step 0: 判断输入类型

根据文件扩展名判断：
- `.pdf` → 跳转到 Step 1 (PDF 处理)
- `.docx` → 跳转到 Step 1a (Word 处理)

---

### Step 1: 读取原始 PDF

使用 `pdfplumber` 完整提取所有页面的文本内容：

```python
import pdfplumber

pdf_path = '用户提供的PDF路径'
with pdfplumber.open(pdf_path) as pdf:
    for i in range(len(pdf.pages)):
        text = pdf.pages[i].extract_text()
        print(f"=== Page {i+1} ===")
        print(text)
```

### Step 1a: 处理 Word 文档

#### 方式一：使用 pandoc（推荐）

```bash
pandoc input.docx -t markdown -o output.md
```

#### 方式二：使用 python-docx

```python
from docx import Document

doc = Document('input.docx')
for para in doc.paragraphs:
    print(para.text)

for table in doc.tables:
    for row in table.rows:
        row_data = [cell.text for cell in row.cells]
        print('|'.join(row_data))
```

### Step 2: 检查并提取图片（如有）

#### PDF 中的图片

检测 PDF 中的嵌入图片：

```python
with pdfplumber.open(pdf_path) as pdf:
    for i, page in enumerate(pdf.pages):
        images = page.images
        if images:
            print(f"Page {i+1}: {len(images)} images")
```

如有图片，提取并保存到 `images/` 目录：

```python
from PIL import Image

output_dir = './images/'
os.makedirs(output_dir, exist_ok=True)

with pdfplumber.open(pdf_path) as pdf:
    for i, page in enumerate(pdf.pages):
        for j, img in enumerate(page.images):
            bbox = (img['x0'], img['top'], img['x0'] + img['width'], img['top'] + img['height'])
            cropped = page.crop(bbox)
            pil_img = cropped.to_image(resolution=300).original
            pil_img.save(f'{output_dir}/page{i+1}_{j+1}.png')
```

#### Word 文档中的图片

Word 文档中的图片嵌入在 `document.xml` 中，需要从文档中提取：

```python
from docx import Document
from docx.oxml.ns import qn
import zipfile
import os

doc = Document('input.docx')

# 提取图片
output_dir = './images/'
os.makedirs(output_dir, exist_ok=True)

# Word 文档是 zip 文件，图片存储在 word/media/ 中
with zipfile.ZipFile('input.docx', 'r') as zip_ref:
    for file in zip_ref.namelist():
        if file.startswith('word/media/'):
            zip_ref.extract(file, output_dir)
            # 重命名文件
            old_name = os.path.join(output_dir, file)
            new_name = os.path.join(output_dir, f"image_{file.split('/')[-1]}")
            if os.path.exists(old_name) and old_name != new_name:
                os.rename(old_name, new_name)
```

在 Markdown 中引用：
```markdown
![描述](./images/page5_1.png)
```

### Step 3: 转换为趋境风格 Markdown

#### 格式要求

| 元素 | 格式 |
|:---|:---|
| 标题 | `# 一级标题`、`## 二级标题` |
| 表格 | 标准 Markdown 表格，用 `\|` 分隔 |
| 比率 | **必须用百分数**，如 `+32%`、`-15%` |
| 范围 | **必须用 `-` 连接**，如 `32%-71%`，**禁止用 `~`** |
| 列表 | 使用 `- ` 或 `* ` |
| 长命令行 | 使用 `\` 拆分为多行，避免超出页面宽度被截断 |

#### 特别注意

- **禁止添加任何原始文档中没有的内容**（如测试时间、测试人、备注等）
- **比率必须是百分数**，不能是小数 (0.32 → +32%)
- **范围连接符必须用 `-`**，不能用 `~`（否则会显示删除线）
- 表格必须对齐，数据与原始文档完全一致

#### Word 转 Markdown 的特殊处理

1. **标题层级**：Word 中的多级标题需要正确转换为 Markdown 标题（# ## ###）
2. **表格**：Word 表格需要转换为 Markdown 表格格式
3. **列表**：Word 的编号列表和项目符号需要转换为 `-` 或 `*`
4. **图片**：Word 中的图片需要提取后用 Markdown 引用

### Step 4: 生成 PDF

```bash
/Users/wuyanlong/work/approaching/code/scenario-based-report/scripts/generate-pdf.sh --name '报告名称-{date}' --doc-type '测试报告' xxx.md
```

---

## 常见错误清单

| 错误类型 | 错误示例 | 正确做法 |
|:---|:---|:---|
| 越权添加 | 添加"测试时间：2025.12.18" | 原始没有就不加 |
| 比率格式 | `0.32` | `+32%` |
| 连接符 | `32~71%` | `32%-71%` |
| 表格格式 | 数据不对齐 | 使用标准 Markdown 表格 |
| 内容错误 | 复制了其他报告内容 | 100% 提取原始文档内容 |
| Word 图片 | 未提取图片 | 使用 zipfile 提取 word/media/ 中的图片 |

---

## 验证清单

生成 PDF 后检查：

- [ ] 内容与原始文档（PDF/Word）完全一致
- [ ] 所有比率是百分数形式
- [ ] 范围用 `-` 连接，无删除线
- [ ] 表格数据正确对齐
- [ ] 图片（如有）正确嵌入
