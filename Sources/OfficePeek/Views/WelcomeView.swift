import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 欢迎主页：支持文件拖拽投放、格式筛选与最近文档缩略图网格
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

    private var dropZoneSection: some View {
        Button {
            appState.pickFileWithPanel()
        } label: {
            VStack(spacing: 10) {
                Text("📂")
                    .font(.system(size: 32))
                Text("拖拽 .docx / .pptx / .xlsx 到此处，或点击选择本地文件")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text("毫秒级离线秒开 · 零服务端依赖 · 原生 CoreGraphics 矢量渲染与高保真导出")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
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
                    Text("点击上方「打开文件…」或拖拽文档到此处开始浏览，打开过的文档会自动生成封面缩略图。")
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

