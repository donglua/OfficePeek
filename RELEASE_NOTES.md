# OfficePeek v0.7.0 发版说明 (Release Notes)

🎉 **OfficePeek v0.7.0 正式发布！**

OfficePeek 是一款专为 macOS 打造的**轻量、极速、离线**的原生 Office 文档查看器，支持 Word (`.docx`)、PowerPoint (`.pptx`) 与 Excel (`.xlsx`) 三大主流格式。底层基于 **JZOfficeKit**（Rust 高性能解析核心 `jz-office-core` 与 Apple `CoreGraphics` / `CoreText` 矢量渲染引擎）构建，无 Electron、无 WebView、零多余后台依赖。

在 **v0.7.0** 版本中，OfficePeek 全面对齐 **JZOfficeKit v0.17.0** 最新核心引擎，新增 **DOCX 脚注与尾注预览**、**PPTX 表格合并单元格与标准面积图**、**XLSX 单元格缩进与自动缩字**，以及多项字体回退与 OOXML 兼容性修复；同时带来了 **原生 macOS 画廊风界面焕新** 与 **缩略图磁盘缓存冷启动加速**。

---

## 🚀 v0.7.0 核心更新亮点

### 1. 接入 JZOfficeKit v0.17.0：三格式预览能力升级
- **DOCX 脚注与尾注静态连续流预览**：
  - 解析 `footnotes` 与 `endnotes` 部件（过滤分隔符等非正文项，按正文首次引用顺序分配连续十进制上标编号）；
  - 在正文末尾按静态连续流追加被引用的脚注与尾注，首条注释上方绘制分隔顶线并保留注释独立关系上下文，支持注释内嵌图片解析与全文检索。
- **PPTX 表格合并单元格与标准面积图**：
  - 支持解析 PPTX 表格单元格 `gridSpan`、`rowSpan` 与 `hMerge` / `vMerge` 合并标记，准确合并绘制跨行跨列单元格；
  - 新增标准面积图（`areaChart`）渲染，沿零基线闭合填充区域、自动拆分正负跨零区段并按 `blanks` 策略处理空值。
- **XLSX 单元格缩进与自动缩字**：
  - 完整支持单元格水平缩进偏移（`indent`，按字符宽度计算，居中对齐自动忽略）及未启用换行时的单行自适应缩字（`shrinkToFit`）。
- **字体回退与 OOXML 兼容修复**：
  - 支持 DOCX 混排文本按字符脚本（ASCII / 东亚 / 复杂脚本）拆分 Run 并保留显式字体族；
  - 扩展 macOS 系统对宋体、仿宋、黑体、楷体、隶书、等线、微软雅黑、幼圆及思源等常见 Office 字体族的回退映射；
  - 择优选择 `mc:AlternateContent` 受支持分支，并支持从旧版 `w:pict` / `w:object` 中提取 `v:imagedata` 图片。

### 2. 原生 macOS 画廊风界面焕新
- **通透单窗欢迎页与分组画廊**：
  - 欢迎主页采用原生 macOS 画廊视觉与毛玻璃（Material）分层设计，新增「已置顶」与「最近打开」分组展示、分段式格式过滤胶囊与相对时间显示（刚刚 / X 小时前 / 昨天）；
  - 支持全窗任意区域文件拖拽导入与半透明拖拽悬浮提示蒙层（Drop Overlay）。
- **阅读器毛玻璃侧边栏与设计系统统一**：
  - 优化阅读器目录/页面缩略图侧边栏材质、页码徽章与主题设计 Token（`ThemeColor` / `ThemeTypography` / `ThemeSpacing` / `ThemeRadius`）。

### 3. 冷启动与列表加载性能优化
- **按需懒加载 + 磁盘缓存**：
  - 欢迎页记录与首页封面彻底解耦：冷启动阶段零阻塞渲染，滚动可视区域按需触发缩略图生成；
  - 引入基于文件修改时间与指纹校验的 PNG 磁盘缓存和有界并发队列，二次启动瞬时命中封面，源文件变更时自动失效重建。

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
1. 从下方 Assets 列表中下载 `OfficePeek-0.7.0-macOS.zip`；
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
