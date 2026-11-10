# OfficePeek

轻量、极速、离线的 macOS 原生 Office 文档查看器（支持 `.docx`、`.pptx`、`.xlsx`），基于 [`JZOffice`](../JZOfficeAndroid/viewer-macos)（Rust `jz-office-core` + Apple `CoreGraphics` / `CoreText`）构建。

## 核心特性

- **毫秒级离线秒开**：底层由 Rust 解析 OOXML 并通过 CoreGraphics 矢量绘制，无需安装 Microsoft Office 或启动臃肿进程，完整 `.app` 包体积仅约 **2.6 MB**（压缩包仅 **~850 KB**）。
- **全文检索与平滑导航**：
  - 支持跨 `.docx`、`.pptx`、`.xlsx` 毫秒级全文关键词检索；
  - 检索命中高亮绘制、命中数量即时统计、当前焦点环形遍历（`Cmd + G` / `Cmd + Shift + G`）与视口平滑自动居中定位。
- **原生文本框选与快捷复制**：
  - 原生支持鼠标自由拖拽框选、双击选词、三击整行/段落；
  - 支持 `Cmd + C` 复制纯文本至系统剪贴板、`Cmd + A` 全选。
- **排版与复杂表格深度还原**：
  - **表格合并单元格**：完整支持 DOCX / PPTX 表格横向与纵向跨行跨列合并（`gridSpan` 与 `vMerge`）；
  - **字体与版式**：支持 OOXML 主题字体（`theme1.xml`）解析、中文字体平滑回退、多级有序/无序编号列表、段落两端对齐拉伸与字符单位缩进。
- **欢迎主页与最近文档封面墙**：
  - 支持直接拖拽 `.docx` / `.pptx` / `.xlsx` 到窗口打开，或双击 Finder 文件关联打开；
  - 自动提取文档元数据（`OfficeMetadata`）并异步渲染首页缩略图（`OfficeThumbnail`），支持按格式过滤（全部 / DOCX / PPTX / XLSX）、搜索与置顶。
- **三格式专属导航侧边栏**：
  - **PPTX**：左侧展示全部幻灯片缩略图导航栏，点击即时定位跳转到对应幻灯片；
  - **XLSX**：左侧工作表目录与底部 `OfficeSheetTabs` 标签栏实时双向联动；
  - **DOCX**：版面尺寸与兼容性提示检查器。
- **矢量 PDF 与高清 PNG 导出**：
  - 一键将当前文档导出为矢量 PDF（`Cmd + E`）或将当前页导出为高清 PNG 图片。

## 下载与安装

### 方式 1：直接下载预编译包（推荐）

1. 前往 [GitHub Releases](https://github.com/donglua/OfficePeek/releases) 下载最新的 `OfficePeek-x.x.x-macOS.zip`（下载仅约 **870 KB**，解压后完整 `.app` 约 **2.6 MB**）；
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
