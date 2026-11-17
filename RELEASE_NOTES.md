# OfficePeek v0.5.0 发版说明 (Release Notes)

🎉 **OfficePeek v0.5.0 正式发布！**

OfficePeek 是一款专为 macOS 打造的**轻量、极速、离线**的原生 Office 文档查看器，支持 Word (`.docx`)、PowerPoint (`.pptx`) 与 Excel (`.xlsx`) 三大主流格式。底层基于 **JZOffice**（Rust 高性能解析核心 `jz-office-core` 与 Apple `CoreGraphics` / `CoreText` 矢量渲染引擎）构建，无 Electron、无 WebView、零多余后台依赖。

在 **v0.5.0** 版本中，OfficePeek 全面对齐 **JZOffice v0.15.0** 最新核心引擎，正式支持 **XLSX 冻结窗格与滚动表头视口锁定**，并完善 **DOCX 行内图片水平对齐、透明不换行 `spAutoFit` 文本框自适配与窄页画布居中展示**。

---

## 🚀 v0.5.0 核心更新亮点

### 1. 接入 JZOffice v0.15.0：XLSX 冻结窗格与表头视口锁定
- **完整冻结窗格解析与渲染**：
  - 支持解析 Excel 工作表 `<sheetViews>/<sheetView>/<pane>` 的 `frozen` 与 `frozenSplit` 状态，覆盖仅冻结行、仅冻结列以及行列交叉冻结，并按工作表行列维度安全钳位；
  - 采用单画布四象限裁剪绘制实现冻结区与滚动区共存，跨冻结边界的合并单元格会在各象限分别平移裁剪绘制，并在冻结交界处绘制 1px `#9aa5b1` 分割线。
- **视口占比保护与检索避让**：
  - 按 X/Y 轴独立判定冻结区是否超过可用正文区的 75%，高倍缩放或小窗口下仅取消超限的轴，避免正文被冻结区挤满；
  - 检索命中高亮按象限裁剪，滚动区高亮绝不覆盖冻结区；检索跳转命中冻结行/列时保持该轴滚动位置，命中滚动区时再居中对齐到可滚动视口中心。
- **长表格外围行列标头锁定**：
  - `.xlsx` 预览画布接入真实滚动视口 `docVisible`，在 `NSScrollView` 滚动时即时重绘，修正长表格滚动时外围行列标头随正文一起滚走的问题。

### 2. DOCX 行内图片水平对齐、自适应文本框与画布居中
- **行内图片保留段落水平对齐**：
  - 保留行内 `<wp:inline>` 图片所在段落的 `jc` 对齐属性（`left` / `center` / `right`），在正文预览、缩略图与 PNG 导出中按 `horizontalAlign` 居中或右对齐绘制。
- **自适应文本框测量修复**：
  - 修复部分无边框透明不换行文本框（`spAutoFit + wrap="none"`）的宽度测量逻辑，避免内容被误换行或截断，并同步至文本选区布局模型。
- **DOCX / PPTX 窄页画布水平居中**：
  - 在宽窗口下查看窄版面 DOCX 文档或 PPTX 幻灯片时，画布自动在滚动视口内水平居中展示；XLSX 工作表仍保持左上角对齐。

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
1. 从下方 Assets 列表中下载 `OfficePeek-0.5.0-macOS.zip`；
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
