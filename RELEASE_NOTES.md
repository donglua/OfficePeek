# OfficePeek v0.3.0 发版说明 (Release Notes)

🎉 **OfficePeek v0.3.0 正式发布！**

OfficePeek 是一款专为 macOS 打造的**轻量、极速、离线**的原生 Office 文档查看器，支持 Word (`.docx`)、PowerPoint (`.pptx`) 与 Excel (`.xlsx`) 三大主流格式。底层基于 **JZOffice**（Rust 高性能解析核心 `jz-office-core` 与 Apple `CoreGraphics` / `CoreText` 矢量渲染引擎）构建，无 Electron、无 WebView、零多余后台依赖。

在 **v0.3.0** 版本中，OfficePeek 全面接入 **JZOffice v0.13.0** 最新核心引擎，带来全端的**段落底纹、段落边框、文本高亮、跨平台字体回退与排版修饰属性（上下标/删除线/字间距/字重）**以及 **Word 文档网格补偿与 PPTX 两端对齐**；同时，应用层迎来了**自发布以来最彻底的 macOS HIG 原生界面与品牌交互升级**！

应用完整体积依然保持在约 **3 MB**（压缩包仅 **~1.1 MB**），冷启动毫秒级秒开！

---

## 🚀 v0.3.0 核心更新亮点

### 1. 接入 JZOffice v0.13.0 高保真排版与字体引擎
- **底纹、边框与文本高亮**：
  - 完整支持 DOCX 文本高亮（`w:highlight`）精确背景矩形绘制；
  - 完整支持段落底纹区域填充（`w:shd`）及段落上下左右与段间边框（`w:pBdr`）矢量绘制，支持安全线宽钳位与线型解析。
- **跨平台字体族解析与排版修饰**：
  - 西文与东亚字体族（`font_family` / `font_family_east_asia`）层叠回退与优先匹配；
  - 支持字间距（`letterSpacing`）、标准化字重（100–900 细权平滑映射）、上下标基线对齐偏移（`baseline`）、单/双删除线（`strike` / `double_strike`）全端矢量渲染；
  - 接入有界 `TypefaceCache`（LRU 字体对象缓存），杜绝高频排版绘制时的重复字体解析开销。
- **高级段落间距与网格补偿**：
  - 支持 Word 标准文档网格行间距补偿算法（`w:docGrid` pitch compensation），精准对齐 Word 标准排版网格；
  - 解析上下文间距标记（`w:contextualSpacing`），自动消除同级段落间的重复边距；
  - PPTX 支持百分比行距、段前段后间距以及两端对齐（Justified Alignment）字符间距平滑拉伸。

### 2. 全新 macOS HIG 现代化原生视觉体系
- **官方 AppIcon 与矢量品牌标识**：
  - 基于 macOS HIG 超椭圆（Squircle）精细矢量几何设计 `BrandLogoView`；
  - 内置官方全尺寸 `AppIcon.icns`，多层 Office 格式折角叠放质感，完美融入 macOS Dock 栏与访达。
- **集中化设计系统 Tokens**：
  - 引入 `ThemeColor`、`ThemeTypography`、`ThemeSpacing`，规范全应用格式主题色（Word 蓝、PPT 橙、Excel 绿）、半透明微调色与排版阶梯。

### 3. 现代化原生 Unified Toolbar 与阅读体验
- **原生统一窗口工具栏**：重构 `DocumentReaderView`，接入 macOS 原生 Unified Window Toolbar，与系统窗口控制按钮无缝融合。
- **标准 HIG 快捷键支持**：
  - 缩放快捷键：`⌘ +`（放大）、`⌘ -`（缩小）、`⌘ 0`（恢复实际大小）；
  - 视图切换快捷键：`⌘ + ⌥ + S`（一键切换侧边栏展开/折叠）。

### 4. 毛玻璃材质侧边栏与卡片提升
- **原生材质侧边栏**：`DocumentSidebarView` 采用 `regularMaterial` 磨砂毛玻璃材质背景，优雅透出桌面背景。
- **悬浮投影与状态卡片**：幻灯片与工作表缩略图卡片采用悬浮微投影与原生 AccentColor 选中高光边框，交互清晰利落。

### 5. 欢迎主页交互进化
- **动态拖拽响应区**：主页拖拽交互支持高亮边界动态反馈，拖入即开。
- **格式统计与筛选 Pills**：顶部格式筛选条支持按 DOCX / PPTX / XLSX 实时显示文档数量徽章。
- **精致最近文档卡片**：`RecentFileCardView` 增加悬停轻投影、格式专用图标与智能路径截断，浏览最近文件更舒适。

---

## ⌨️ 常用快捷键速查

| 操作 | 快捷键 |
| :--- | :--- |
| **打开文档** | `⌘ + O` |
| **返回欢迎主页** | `⌘ + ⇧ + W` |
| **导出为矢量 PDF** | `⌘ + E` |
| **全文检索** | `⌘ + F` |
| **查找下一个匹配项** | `⌘ + G` |
| **查找上一个匹配项** | `⌘ + ⇧ + G` |
| **关闭查找栏** | `Esc` |
| **复制选中文本** | `⌘ + C` |
| **全选文档内容** | `⌘ + A` |
| **上一页 / 上一个工作表** | `⌘ + ←` |
| **下一页 / 下一个工作表** | `⌘ + →` |
| **放大 / 缩小 / 实际大小** | `⌘ + +` / `⌘ + -` / `⌘ + 0` |
| **切换显示侧边栏** | `⌘ + ⌥ + S` |

---

## 📦 安装与运行

### 方式 1：直接下载使用预编译安装包（推荐）
1. 从下方 Assets 列表中下载 `OfficePeek-0.3.0-macOS.zip`；
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
