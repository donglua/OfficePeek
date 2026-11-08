# OfficePeek

轻量、极速、离线的 macOS 原生 Office 文档查看器（支持 `.docx`、`.pptx`、`.xlsx`），基于 [`JZOffice`](../JZOfficeAndroid/viewer-macos)（Rust `jz-office-core` + Apple `CoreGraphics` / `CoreText`）构建。

## 核心特性

- **毫秒级离线秒开**：底层由 Rust 解析 OOXML 并通过 CoreGraphics 矢量绘制，无需安装 Microsoft Office 或启动臃肿进程，完整 `.app` 包体积仅约 **3~4 MB**。
- **欢迎主页与最近文档封面墙**：
  - 支持直接拖拽 `.docx` / `.pptx` / `.xlsx` 到窗口打开，或双击 Finder 文件关联打开；
  - 自动提取文档元数据（`OfficeMetadata`）并异步渲染首页缩略图（`OfficeThumbnail`），支持按格式过滤（全部 / DOCX / PPTX / XLSX）、搜索与置顶。
- **三格式专属导航侧边栏**：
  - **PPTX**：左侧展示全部幻灯片缩略图导航栏，点击即时定位跳转到对应幻灯片；
  - **XLSX**：左侧工作表目录与底部 `OfficeSheetTabs` 标签栏实时双向联动；
  - **DOCX**：版面尺寸与兼容性提示检查器。
- **矢量 PDF 与高清 PNG 导出**：
  - 一键将当前文档导出为矢量 PDF（`Cmd + E`）或将当前页导出为高清 PNG 图片。

## 构建与运行

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
