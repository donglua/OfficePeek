# OfficePeek

轻量、极速、离线的 macOS 原生 Office 文档查看器（支持 `.docx`、`.pptx`、`.xlsx`、`.csv`、`.tsv`），基于 [`JZOfficeKit`](https://github.com/donglua/JZOfficeKit)（Rust `jz-office-core` + Apple `CoreGraphics` / `CoreText`）构建。

## 核心特性

- **毫秒级离线秒开**：底层由 Rust 解析 OOXML 并通过 CoreGraphics 矢量绘制，无需安装 Microsoft Office 或启动臃肿进程，完整 `.app` 包体积保持数 MB 级别，冷启动秒开。
- **全文检索与按需索引预热**：
  - 支持跨 `.docx`、`.pptx`、`.xlsx`、`.csv`、`.tsv` 毫秒级全文关键词检索（含 DOCX 浮动形状文本框内容）；
  - 常规打开与封面扫描零索引开销，呼出查找栏（`Cmd + F`）时后台按需预热索引；
  - 检索命中高亮绘制（自适应浮动环绕与 XLSX 冻结象限裁剪）、命中数量即时统计、当前焦点环形遍历（`Cmd + G` / `Cmd + Shift + G`）与视口平滑自动居中/冻结区避让定位。
- **原生文档框选与快捷复制**：
  - **DOCX / PPTX**：原生支持鼠标自由拖拽框选、双击选词、三击整行/段落；
  - **XLSX / CSV / TSV 单元格与区域选择复制**：支持 `.xlsx` 以及 `.csv` / `.tsv`（自动识别 UTF-8 / UTF-16 / GB18030·GBK 编码与 `,` / `;` / `\t` 分隔符），支持鼠标点选与拖拽框选（含合并单元格不动点闭包吸附、跨冻结边界四象限高亮裁剪、行列标头联动高亮），输出标准 TSV（自动跳过隐藏行列、按 RFC 4180 转义）；
  - 全格式支持 `Cmd + C` 复制至系统剪贴板、`Cmd + A` 全选与右键快捷菜单。
- **排版与复杂图形深度还原**：
  - **XLSX 工作表浮动图形、图表、数字格式与冻结窗格**：支持工作表浮动图片（`<xdr:pic>`，含裁剪/旋转/翻转/描边）、DrawingML 形状（`<xdr:sp>`）、连接线（`<xdr:cxnSp>`）与嵌套组合图形（`<xdr:grpSp>`）按需解码及 PDF/PNG 导出；支持工作表内嵌图表；扩展货币/区域货币、会计格式、单位字面量、千分位缩放、科学计数法、通用自定义日期时间模板与 `t="d"` ISO 8601 日期格式化；支持仅冻结行、仅冻结列与行列交叉冻结，单画布四象限裁剪绘制、跨冻结边界合并单元格、75% 视口占比保护、长表格滚动时外围行列标头与冻结分隔线视口锁定，以及单元格缩进（`indent`）与自动缩字（`shrinkToFit`）；
  - **PPTX 多类型图表、SmartArt、OLE 预览与合并表格**：支持条形图（`barChart`）、饼图与环形图（`pieChart` / `doughnutChart`）、面积图（`areaChart`）、堆叠/百分比堆叠图表、3D 图表 2D 扁平化、组合图与次坐标轴、散点图（`scatterChart`）与雷达图（`radarChart`）、基础数据标签与图例/点样式自适应；支持 SmartArt 缓存图形渲染、嵌入式 OLE 对象缓存预览图、`mc:AlternateContent` 分支解包、表格合并单元格（`gridSpan` / `rowSpan` / `hMerge` / `vMerge`）、26 种高频预设几何、`prstDash` 虚线描边与连接线箭头端点（`triangle` / `stealth` / `arrow` / `diamond` / `oval`）；
  - **DOCX 内嵌图表、脚注尾注、表格样式与浮动排版**：支持 `<wp:inline>` 与 `<wp:anchor>` 内嵌图表；支持脚注与尾注静态连续流预览（含分隔顶线与内嵌图片）、单元格四边独立边框、背景底纹、垂直对齐（顶部/居中/底部）、横向与纵向合并单元格（`gridSpan` 与 `vMerge`），以及 `<wp:anchor>` 浮动定位、环绕模式、Z-order 分层绘制、行内图片水平对齐（左/中/右）、透明不换行 `spAutoFit` 文本框宽度自适配、旧版 VML 图片提取与 DOCX/PPTX 窄页水平居中；
  - **字体、版式与段落修饰**：支持 OOXML 主题字体（`theme1.xml`）解析、DOCX 混排脚本字体拆分、常见 Office 字体（宋体/仿宋/黑体/楷体/隶书/等线/微软雅黑/幼圆/思源等）系统平滑回退、多级列表、段落底纹、段落边框、文本高亮、上下标、删除线、两端对齐拉伸与 Word 文档网格（`docGrid`）行间距补偿。
- **原生 macOS 画廊风主页与极速冷启动**：
  - 通透单窗画廊风设计，支持全窗直接拖拽 `.docx` / `.pptx` / `.xlsx` / `.csv` / `.tsv` 到窗口打开，或双击 Finder 文件关联打开；
  - 通过轻量元数据速读（`OfficeMetadata.readAsync`）、首屏按需封面渲染（`OfficeThumbnail`）与磁盘缩略图缓存 + 有界并发队列实现零阻塞冷启动，支持按格式分段筛选（全部 / DOCX / PPTX / XLSX）、搜索以及已置顶/最近打开分区管理。
- **PPTX 全屏演示模式**：
  - 工具栏「播放」或 `⌘↩`（从当前页）/ `⌘⇧↩`（从头）进入独立无边框全屏放映窗口，多显示器时可选择播放屏幕；
  - 方向键 / 空格 / 回车 / `PageUp` `PageDown`、鼠标单击（右键上一页）、触控板滑动与滚轮翻页，数字 + 回车跳页；
  - `B` / `W` 黑屏与白屏、`L` 激光笔、自动隐藏的页码 HUD 与光标，`Esc` 退出并同步阅读位置。
- **三格式专属导航侧边栏**：
  - **PPTX**：左侧展示全部幻灯片缩略图导航栏，点击即时定位跳转到对应幻灯片；
  - **XLSX**：左侧工作表目录与底部 `OfficeSheetTabs` 标签栏实时双向联动；
  - **DOCX**：版面尺寸与兼容性提示检查器。
- **矢量 PDF 与高清 PNG 导出**：
  - 一键将当前文档导出为矢量 PDF（`Cmd + E`）或将当前页导出为高清 PNG 图片。

## 下载与安装

### 方式 1：直接下载预编译包（推荐）

1. 前往 [GitHub Releases](https://github.com/donglua/OfficePeek/releases) 下载最新的 `OfficePeek-x.x.x-macOS.zip`；
2. 解压后将 `OfficePeek.app` 拖入 `/Applications`（应用程序）目录；
3. 双击直接启动。

> [!TIP]
> **温馨提示（macOS 安全拦截处理）**：  
> 若初次打开时提示 *“Apple无法验证‘OfficePeek’是否包含可能危害Mac安全或泄漏隐私的恶意软件”*，这是 macOS Gatekeeper 对未公证网络下载文件的默认隔离保护。只需打开终端执行以下命令即可彻底解除拦截：
> ```bash
> xattr -cr /Applications/OfficePeek.app
> ```
> *(注：该命令会移除文件的 `com.apple.quarantine` 下载隔离属性，执行后即可正常双击秒开)*

### 方式 2：从源码构建运行

```sh
# 1. 运行测试并打包 build/OfficePeek.app
chmod +x scripts/build-app.sh
./scripts/build-app.sh

# 2. 启动 OfficePeek.app
open build/OfficePeek.app
```

也可以直接通过 SwiftPM 命令行调试运行：

```sh
swift run OfficePeek
```
