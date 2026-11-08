import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 欢迎主页：支持文件拖拽投放、内置样例秒开、格式筛选与最近文档缩略图网格
struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var recentStore: RecentFilesStore

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    dropZoneAndSamplesSection
                    recentFilesSection
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedProviders(providers)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.42, blue: 0.95),
                                Color(red: 0.08, green: 0.65, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                Text("OP")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("OfficePeek")
                    .font(.system(size: 18, weight: .bold))
                Text("基于 Rust 核心的极速、轻量、只读 macOS Office 文档查看器")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            TextField("搜索最近文档...", text: $recentStore.searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 210)

            Button {
                appState.pickFileWithPanel()
            } label: {
                Text("打开文件…")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var dropZoneAndSamplesSection: some View {
        HStack(spacing: 16) {
            Button {
                appState.pickFileWithPanel()
            } label: {
                VStack(spacing: 8) {
                    Text("📂")
                        .font(.system(size: 28))
                    Text("拖拽 .docx / .pptx / .xlsx 到窗口任意位置，或点击选择本地文件")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text("离线秒开 · 零服务端依赖 · 原生 CoreGraphics 矢量渲染")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 108)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundColor(Color.accentColor.opacity(0.45))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.opacity(0.04))
                        )
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text("内置综合样例快速体验")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                ForEach(SampleLocator.sampleItems, id: \.fileName) { sample in
                    Button {
                        if let url = SampleLocator.resolveSampleURL(named: sample.fileName) {
                            appState.openDocument(at: url)
                        } else {
                            appState.showToast("未找到内置样例 \(sample.fileName)")
                        }
                    } label: {
                        HStack(spacing: 10) {
                            FormatBadgeView(kind: sample.kind, compact: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sample.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(sample.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("打开 →")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 340)
        }
    }

    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("最近打开")
                    .font(.system(size: 15, weight: .bold))

                filterPill(title: "全部", kind: nil)
                filterPill(title: "DOCX", kind: .docx)
                filterPill(title: "PPTX", kind: .pptx)
                filterPill(title: "XLSX", kind: .xlsx)

                Spacer()

                if !recentStore.records.isEmpty {
                    Button("清理失效路径") {
                        recentStore.pruneMissingFiles()
                    }
                    .font(.system(size: 12))
                }
            }

            let items = recentStore.filteredRecords
            if items.isEmpty {
                VStack(spacing: 8) {
                    Text("暂无匹配的最近文档记录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("点击上方「打开文件…」或右侧「内置综合样例」开始浏览，打开过的文档会自动生成封面缩略图。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(items) { item in
                        RecentFileCardView(
                            item: item,
                            thumbnail: recentStore.thumbnails[item.id],
                            onOpen: { appState.openDocument(at: item.fileURL) },
                            onTogglePin: { recentStore.togglePin(for: item.id) },
                            onExportPDF: { appState.exportPDF(for: item.fileURL) },
                            onReveal: { appState.revealInFinder(item.fileURL) },
                            onRemove: { recentStore.remove(id: item.id) }
                        )
                        .task {
                            await recentStore.loadThumbnailIfNeeded(for: item)
                        }
                    }
                }
            }
        }
    }

    private func filterPill(title: String, kind: OfficeKind?) -> some View {
        let isSelected = recentStore.selectedFormatFilter == kind
        return Button {
            recentStore.selectedFormatFilter = kind
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            Task { @MainActor in
                appState.openDocument(at: url)
            }
        }
        return true
    }
}

private struct RecentFileCardView: View {
    let item: RecentFileRecord
    let thumbnail: NSImage?
    let onOpen: () -> Void
    let onTogglePin: () -> Void
    let onExportPDF: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Color(nsColor: NSColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1.0))
                        if let thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(height: 140)
                    .clipped()

                    HStack(spacing: 6) {
                        if item.isPinned {
                            Text("📌")
                                .font(.system(size: 11))
                                .padding(4)
                                .background(Circle().fill(Color.white.opacity(0.9)))
                        }
                        FormatBadgeView(kind: item.format, compact: true)
                    }
                    .padding(8)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.pageSummary)
                        Text("·")
                        Text(item.formattedFileSize)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("打开文档", action: onOpen)
            Button(item.isPinned ? "取消固定" : "固定到顶部", action: onTogglePin)
            Divider()
            Button("导出为矢量 PDF…", action: onExportPDF)
            Button("在 Finder 中显示", action: onReveal)
            Divider()
            Button("从最近列表中移除", role: .destructive, action: onRemove)
        }
    }
}
