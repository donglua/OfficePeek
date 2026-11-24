# OfficePeek v0.8.0 发版说明 (Release Notes)

🎉 **OfficePeek v0.8.0 正式发布！**

OfficePeek 是一款专为 macOS 打造的**轻量、极速、离线**的原生 Office 文档查看器，支持 Word (`.docx`)、PowerPoint (`.pptx`)、Excel (`.xlsx`) 以及纯文本表格 (`.csv`、`.tsv`)。底层基于 **JZOfficeKit**（Rust 高性能解析核心 `jz-office-core` 与 Apple `CoreGraphics` / `CoreText` 矢量渲染引擎）构建，无 Electron、无 WebView、零多余后台依赖。

在 **v0.8.0** 版本中，OfficePeek 全面对齐 **JZOfficeKit v0.18.0 ~ v0.19.0** 最新核心引擎，新增 **XLSX 工作表浮动图片/形状/连接线/组合图形渲染与导出**、**DOCX 与 XLSX 内嵌图表**、**PPTX 堆叠/3D/组合/散点/雷达图与 SmartArt/OLE 预览**、**XLSX 扩展数字/ISO 日期格式** 及 **CSV / TSV 纯文本表格预览**，并带来全新 **PPTX 全屏演示模式** 与多项预览对齐/命中偏移修复。

---

## 🚀 v0.8.0 核心更新亮点

### 1. 接入 JZOfficeKit v0.19.0：XLSX 浮动图形、数字格式与 CSV / TSV 支持
- **XLSX 工作表浮动图片、形状、连接线与组合图形**：
  - 支持渲染与导出工作表 `<xdr:pic>` 浮动图片（含裁剪、旋转/翻转与描边）、`<xdr:sp>` DrawingML 形状、`<xdr:cxnSp>` 连接线与最多 16 层 `<xdr:grpSp>` 嵌套组合图形；
  - `OfficePageRenderer` 同步接入视口可见图片预取与按需解码，确保导出单页 PNG 与主画布/PDF 导出观感一致。
- **XLSX 数字格式与 ISO 日期扩展**：
  - 支持货币/区域货币标签（`$#,##0.00`、`[$¥-804]#,##0.00`）、会计格式（`numFmtId 37..=44`）、单位字面量（`0" kg"`）、千分位缩放逗号（`#,##0.0,," M"`）、科学计数法（`0.00E+00`）、通用自定义日期时间模板与 `t="d"` ISO 8601 日期单元格。
- **CSV / TSV 纯文本表格原生预览**：
  - 支持通过拖拽、文件选择面板或 Finder 文件关联直接打开 `.csv` / `.tsv`，自动探测 UTF-8 / UTF-16 / GB18030·GBK 编码与 `,` / `;` / `\t` 分隔符，支持全文检索、区域选区与标准 TSV 复制。
- **预览对齐与命中偏移修复**：
  - 修复非表格/表格预览视图左上对齐偏移以及 XLSX 点击/选区坐标命中偏移问题。

### 2. 接入 JZOfficeKit v0.18.0：跨格式图表引擎与 PPTX 兼容升级
- **DOCX & XLSX 内嵌图表**：
  - 支持 DOCX（`<wp:inline>` / `<wp:anchor>`）与 XLSX（冻结四象限裁剪、滚动与缩略图）内嵌图表渲染。
- **PPTX 图表与图形扩展**：
  - 支持堆叠/百分比堆叠图表（柱状/条形/折线/面积）、3D 图表 2D 扁平化、组合图与次坐标轴、散点图（`scatterChart`）、雷达图（`radarChart`）、基础数据标签与 `<c:dPt>` 单点样式；
  - 新增 SmartArt 缓存图形（`diagramDrawing`）渲染、嵌入式 OLE 对象缓存预览图与 `mc:AlternateContent` 分支解包；
  - 优化缺失字体回退预检，避免未安装字体触发系统查找阻塞。

### 3. PPTX 全屏演示模式
- **独立无边框全屏放映**：
  - 支持工具栏「播放」或 `⌘↩`（从当前页）/ `⌘⇧↩`（从头）进入独立全屏放映窗口，多显示器环境支持选择指定播放屏幕；
  - 支持方向键 / 空格 / 回车 / `PageUp` `PageDown`、鼠标单击/右键、触控板滑动/滚轮翻页及「数字 + 回车」快速跳页；
  - 内置 `B` / `W` 黑白屏切换、`L` 激光笔、自动隐藏的页码 HUD 与光标，`Esc` 退出时自动将阅读视图同步回当前幻灯片。

---

## ⌨️ 常用快捷键速查

| 操作 | 快捷键 |
| :--- | :--- |
| **打开文档** | `⌘ + O` |
| **返回欢迎主页** | `⌘ + W` |
| **导出为矢量 PDF** | `⌘ + E` |
| **全文检索** | `⌘ + F` |
| **查找下一个匹配项** | `⌘ + G` |
| **查找上一个匹配项** | `⌘ + ⇧ + G` |
| **关闭查找栏** | `Esc` |
| **复制选中文本** | `⌘ + C` |
| **全选文档内容** | `⌘ + A` |
| **上一页 / 上一个工作表** | `⌘ + ←` |
| **下一页 / 下一个工作表** | `⌘ + →` |
| **从当前页 / 从头开始演示 (PPTX)** | `⌘ + ↩` / `⌘ + ⇧ + ↩` |
| **演示黑白屏 / 激光笔 / 退出** | `B` / `W` / `L` / `Esc` |
| **放大 / 缩小 / 实际大小** | `⌘ + =` / `⌘ + -` / `⌘ + 0` |
| **切换显示侧边栏** | `⌘ + \` |

---

## 📦 安装与运行

### 方式 1：直接下载使用预编译安装包（推荐）
1. 从下方 Assets 列表中下载 `OfficePeek-0.8.0-macOS.zip`；
2. 解压后将 `OfficePeek.app` 拖入 `/Applications` 应用程序文件夹；
3. 双击即可极速启动。

> [!TIP]
> **温馨提示（macOS 安全拦截处理）**：  
> 若初次打开时提示 *“Apple无法验证‘OfficePeek’是否包含可能危害Mac安全或泄漏隐私的恶意软件”*，这是 macOS 对未公证网络下载文件的默认隔离保护。只需打开终端执行以下命令即可彻底解除拦截：
> ```bash
> xattr -cr /Applications/OfficePeek.app
> ```
> *(该命令用于递归移除文件的 `com.apple.quarantine` 隔离属性，执行后即可正常双击秒开)*

### 方式 2：通过源码构建
```sh
git clone https://github.com/donglua/OfficePeek.git
cd OfficePeek
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open build/OfficePeek.app
```

---

**感谢关注与使用 OfficePeek！如有任何问题或改进建议，欢迎提交 Issue 与 PR 交流！**
