# OfficePeek v0.4.0 发版说明 (Release Notes)

🎉 **OfficePeek v0.4.0 正式发布！**

OfficePeek 是一款专为 macOS 打造的**轻量、极速、离线**的原生 Office 文档查看器，支持 Word (`.docx`)、PowerPoint (`.pptx`) 与 Excel (`.xlsx`) 三大主流格式。底层基于 **JZOffice**（Rust 高性能解析核心 `jz-office-core` 与 Apple `CoreGraphics` / `CoreText` 矢量渲染引擎）构建，无 Electron、无 WebView、零多余后台依赖。

在 **v0.4.0** 版本中，OfficePeek 全面接入 **JZOffice v0.14.0** 最新核心引擎，正式支持 **DOCX 浮动图形、DrawingML 形状/文本框与文字环绕全端排版**，并引入**轻量元数据速读、首屏范围封面渲染、多级解析结果缓存复用与按需预热的全文检索管线**；同时修复了侧边栏多页幻灯片缩略图与第 2+ 页 PNG 导出在首屏截断路径下的缓存一致性问题。

---

## 🚀 v0.4.0 核心更新亮点

### 1. 接入 JZOffice v0.14.0：DOCX 浮动图形、DrawingML 形状与文字环绕
- **浮动锚点定位与环绕模式**：
  - 完整支持 `<wp:anchor>` 浮动定位、水平对齐、层级关系（`behindDoc`）与四向环绕边距；
  - 支持四周型（`SQUARE`）、上下型（`TOP_AND_BOTTOM`）、紧密型（`TIGHT`）、穿越型（`THROUGH`）、衬于文字下方与浮于文字上方等环绕排版，同时保持无环绕段落流的连续性。
- **DrawingML 形状、组合图形与文本框**：
  - 支持解析 `<wps:wsp>` / `<wpg:wgp>` 图形与形状内部文本框（`<wps:txbx>`）；
  - 全链路实现浮动元素 Z-order 分层绘制、文字避让环绕排布，以及检索高亮与文本选区坐标精准对齐。

### 2. 轻量元数据速读与首屏封面渲染管线
- **异步轻量元数据速读**：
  - `RecentFilesStore` 接入 `OfficeMetadata.readAsync`（底层使用 `jz_office_metadata_path`），仅读取判定格式与页数所需的少量 ZIP 部件，不再触发整篇文档样式、几何与正文解析，且不阻塞主线程；
  - 同一文档发生内容变更后重新打开时，自动更新元数据记录并刷新首页封面缩略图。
- **首屏范围缩略图与解析结果缓存**：
  - 欢迎页封面缩略图走 `FirstViewport` 首屏范围解析（PPTX 仅渲染首张幻灯片、XLSX 仅解析首个工作表、DOCX 仅解析首屏正文块），大幅降低首页最近文档墙的扫描成本；
  - 底层按「文件路径 + 大小 + 修改时间 + 解析范围」复用解析结果缓存，连续执行「元数据 → 缩略图 → 打开预览」不再重复解析。

### 3. 延迟全文检索索引与按需预热
- **冷启动零索引开销**：文档打开解析阶段不再同步构建全文检索索引，改为首次检索时按需建立轻量索引；
- **查找面板即开即预热**：用户通过 `⌘F` 或工具栏查找按钮打开检索栏时，应用后台异步触发 `NativeCore.prewarmSearchIndexAsync` 预热当前文档索引；切换或关闭文档时自动取消未完成的预热任务。

### 4. 多页缩略图与按页 PNG 导出可靠性修复
- **独立按页渲染器 `OfficePageRenderer`**：
  - 针对阅读器侧边栏 PPTX 多页缩略图（`PageThumbnailCache`）与「导出当前页为高清 PNG」，改为基于当前文档的完整解析结果按页渲染，避免 `FirstViewport` 首屏截断导致第 2+ 页幻灯片或第 2+ 个工作表内容缺失；
  - 同一文档多个侧栏幻灯片共享单次文档解析任务，且按页渲染期间不再调用 `evictCache`，避免清退正在阅读文档的解析缓存与检索索引。

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
| **放大 / 缩小 / 实际大小** | `⌘ + =` / `⌘ + -` / `⌘ + 0` |
| **切换显示侧边栏** | `⌘ + \` |

---

## 📦 安装与运行

### 方式 1：直接下载使用预编译安装包（推荐）
1. 从下方 Assets 列表中下载 `OfficePeek-0.4.0-macOS.zip`；
2. 解压后将 `OfficePeek.app` 拖入 `/Applications` 应用程序文件夹；
3. 双击即可极速启动。

> [!TIP]
> **温馨提示（macOS 安全拦截处理）**：  
> 若初次打开时提示 *“Apple无法验证‘OfficePeek’是否包含可能危害Mac安全或泄漏隐私的恶意软件”*，这是 macOS 对未公证网络下载软件的 Gatekeeper 隔离保护。只需在终端执行以下命令即可彻底解除拦截：
> ```bash
> xattr -cr /Applications/OfficePeek.app
> ```
> *(该命令用于递归移除文件的 `com.apple.quarantine` 隔离属性，执行后即可正常双击秒开)*

### 方式 2：通过源码构建
```bash
git clone https://github.com/donglua/OfficePeek.git
cd OfficePeek
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open build/OfficePeek.app
```

---

**感谢关注与使用 OfficePeek！如有任何问题或改进建议，欢迎提交 Issue 与 PR 交流！**
