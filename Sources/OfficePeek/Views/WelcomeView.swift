import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 欢迎主页：支持文件拖拽投放、格式筛选与最近文档缩略图网格
struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var recentStore: RecentFilesStore

    private var _isDragTargeted: State<Bool> = State(initialValue: false)
    private var isDragTargeted: Bool {
        get { _isDragTargeted.wrappedValue }
        nonmutating set { _isDragTargeted.wrappedValue = newValue }
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    private var docxCount: Int {
        recentStore.records.filter { $0.format == .docx }.count
    }

    private var pptxCount: Int {
        recentStore.records.filter { $0.format == .pptx }.count
    }

    private var xlsxCount: Int {
        recentStore.records.filter { $0.format == .xlsx }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    dropZoneSection
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
            BrandLogoView(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    Text("OfficePeek")
                        .font(ThemeTypography.heroTitle)
                    Text("v0.3.0")
                        .font(ThemeTypography.captionBadge)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                Text("基于 Rust 核心的极速、轻量、只读 macOS Office 文档查看器")
                    .font(ThemeTypography.bodySecondary)
                    .foregroundColor(.secondary)
            }

            Spacer()

            searchField

            Button {
                appState.pickFileWithPanel()
            } label: {
                Label("打开文件…", systemImage: "plus.circle.fill")
                    .font(ThemeTypography.windowTitle)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            TextField("搜索最近文档...", text: $recentStore.searchQuery)
                .textFieldStyle(.plain)
                .font(ThemeTypography.bodyPrimary)
            if !recentStore.searchQuery.isEmpty {
                Button {
                    recentStore.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .frame(width: 220)
    }

    private var dropZoneSection: some View {
        Button {
            appState.pickFileWithPanel()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isDragTargeted ? Color.accentColor : Color.accentColor.opacity(0.8))

                Text("拖拽 .docx / .pptx / .xlsx 到此处，或点击选择本地文件")
                    .font(ThemeTypography.bodyPrimary.weight(.semibold))
                    .foregroundColor(.primary)

                Text("毫秒级离线秒开 · 零服务端依赖 · 原生 CoreGraphics 矢量渲染与高保真导出")
                    .font(ThemeTypography.bodySecondary)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDragTargeted ? Color.accentColor.opacity(0.08) : Color.accentColor.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: isDragTargeted ? 2.0 : 1.5, dash: [6, 4])
                    )
                    .foregroundColor(isDragTargeted ? Color.accentColor : Color.accentColor.opacity(0.35))
            )
            .scaleEffect(isDragTargeted ? 1.01 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragTargeted)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: _isDragTargeted.projectedValue) { providers in
            handleDroppedProviders(providers)
        }
    }

    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("最近打开")
                    .font(.system(size: 15, weight: .bold))

                filterPill(title: "全部", count: recentStore.records.count, kind: nil)
                filterPill(title: "DOCX", count: docxCount, kind: .docx)
                filterPill(title: "PPTX", count: pptxCount, kind: .pptx)
                filterPill(title: "XLSX", count: xlsxCount, kind: .xlsx)

                Spacer()

                if !recentStore.records.isEmpty {
                    Button {
                        recentStore.pruneMissingFiles()
                    } label: {
                        Label("清理失效记录", systemImage: "trash")
                            .font(ThemeTypography.bodySecondary)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            let items = recentStore.filteredRecords
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("暂无匹配的最近文档记录")
                        .font(ThemeTypography.bodyPrimary.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("点击上方「打开文件…」或拖拽文档到此处开始浏览，打开过的文档会自动生成封面缩略图。")
                        .font(ThemeTypography.bodySecondary)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
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

    private func filterPill(title: String, count: Int, kind: OfficeKind?) -> some View {
        let isSelected = recentStore.selectedFormatFilter == kind
        return Button {
            recentStore.selectedFormatFilter = kind
        } label: {
            Text("\(title) (\(count))")
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: recentStore.selectedFormatFilter)
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let targetURL: URL?
            if let url = item as? URL {
                targetURL = url
            } else if let nsURL = item as? NSURL {
                targetURL = nsURL as URL
            } else if let data = item as? Data {
                targetURL = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                targetURL = nil
            }
            guard let url = targetURL else { return }
            Task { @MainActor in
                appState.openDocument(at: url)
            }
        }
        return true
    }
}
