import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 欢迎主页：通透单窗画廊风，支持全窗拖拽投放、分段筛选与已置顶/最近打开分区
struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var recentStore: RecentFilesStore

    private typealias ViewState = SwiftUI.State
    @ViewState private var isDragTargeted = false
    @ViewState private var isPruneHovered = false
    @ViewState private var isHeroHovered = false
    @FocusState private var isSearchFocused: Bool
    @Namespace private var filterPillNamespace

    init(appState: AppState, recentStore: RecentFilesStore) {
        self.appState = appState
        self.recentStore = recentStore
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 224, maximum: 280), spacing: 16)
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                Rectangle()
                    .fill(ThemeColor.hairlineSeparator)
                    .frame(height: 1)

                if recentStore.records.isEmpty {
                    emptyStateHero
                } else {
                    galleryBody
                }
            }
            .background(ThemeColor.windowBackground)

            DropOverlayView(isTargeted: isDragTargeted)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            DropOverlayView.extractFirstFileURL(from: providers) { url in
                appState.openDocument(at: url)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                BrandLogoView(size: 28)

                Text("OfficePeek")
                    .font(ThemeTypography.brandTitle)

                Text("v0.8.0")
                    .font(ThemeTypography.sidebarBadge)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(ThemeColor.segmentedTrackBackground)
                    )
            }

            Spacer()

            if !recentStore.records.isEmpty {
                searchField
            }

            Button {
                appState.pickFileWithPanel()
            } label: {
                Label("打开文件…", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchFocused ? .accentColor : .secondary)
                .font(.system(size: 11.5, weight: .medium))

            TextField("搜索最近文档...", text: $recentStore.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isSearchFocused)

            if !recentStore.searchQuery.isEmpty {
                Button {
                    recentStore.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5.5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ThemeColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSearchFocused ? ThemeColor.elevatedBorder : ThemeColor.subtleBorder,
                    lineWidth: isSearchFocused ? 1.2 : 0.75
                )
        )
        .frame(width: 220)
        .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
    }

    private var galleryBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                filterBar

                if recentStore.filteredRecords.isEmpty {
                    emptyFilterState
                } else {
                    let pinned = recentStore.pinnedFilteredRecords
                    let unpinned = recentStore.unpinnedFilteredRecords

                    if !pinned.isEmpty {
                        gallerySection(
                            title: "已置顶",
                            systemImage: "pin.fill",
                            iconColor: .orange,
                            items: pinned
                        )
                    }

                    if !unpinned.isEmpty {
                        gallerySection(
                            title: "最近打开",
                            systemImage: nil,
                            iconColor: .secondary,
                            items: unpinned
                        )
                    }
                }
            }
            .padding(24)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                filterPill(title: "全部", count: recentStore.records.count, kind: nil)
                filterPill(title: "DOCX", count: recentStore.docxCount, kind: .docx)
                filterPill(title: "PPTX", count: recentStore.pptxCount, kind: .pptx)
                filterPill(title: "XLSX", count: recentStore.xlsxCount, kind: .xlsx)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                    .fill(ThemeColor.segmentedTrackBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                    .strokeBorder(ThemeColor.hairlineSeparator, lineWidth: 0.5)
            )

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    recentStore.pruneMissingFiles()
                }
            } label: {
                Label("清理失效记录", systemImage: "trash")
                    .font(ThemeTypography.bodySecondary)
                    .foregroundColor(isPruneHovered ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isPruneHovered ? ThemeColor.hoverBackground : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isPruneHovered = hovering
            }
        }
    }

    private func filterPill(title: String, count: Int, kind: OfficeKind?) -> some View {
        let isSelected = recentStore.selectedFormatFilter == kind
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                recentStore.selectedFormatFilter = kind
            }
        } label: {
            HStack(spacing: 5) {
                if let kind {
                    Circle()
                        .fill(ThemeColor.color(for: kind))
                        .frame(width: 6, height: 6)
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text("\(count)")
                    .font(ThemeTypography.sidebarBadge)
                    .monospacedDigit()
                    .foregroundColor(isSelected ? .secondary : .secondary.opacity(0.75))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(ThemeColor.segmentedPillBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                        .matchedGeometryEffect(id: "ActiveFilterPill", in: filterPillNamespace)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func gallerySection(
        title: String,
        systemImage: String?,
        iconColor: Color,
        items: [RecentFileRecord]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(ThemeTypography.sectionHeader)
                    .foregroundColor(.secondary)

                Text("\(items.count)")
                    .font(ThemeTypography.sidebarBadge)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(items) { item in
                    RecentFileCardView(
                        item: item,
                        thumbnail: recentStore.thumbnails[item.id],
                        onOpen: { appState.openDocument(at: item.fileURL) },
                        onTogglePin: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                recentStore.togglePin(for: item.id)
                            }
                        },
                        onExportPDF: { appState.exportPDF(for: item.fileURL) },
                        onReveal: { appState.revealInFinder(item.fileURL) },
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                recentStore.remove(id: item.id)
                            }
                        }
                    )
                    .task {
                        await recentStore.loadThumbnailIfNeeded(for: item)
                    }
                }
            }
        }
    }

    private var emptyStateHero: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                BrandLogoView(size: 64)

                VStack(spacing: 6) {
                    Text("欢迎使用 OfficePeek")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("基于 Rust 核心的极速、轻量、只读 macOS Office 文档查看器")
                        .font(ThemeTypography.bodyPrimary)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    FormatBadgeView(kind: .docx)
                    FormatBadgeView(kind: .pptx)
                    FormatBadgeView(kind: .xlsx)
                    FormatBadgeView(kind: .xlsx, label: "CSV")
                    FormatBadgeView(kind: .xlsx, label: "TSV")
                }
                .padding(.top, 2)
            }

            Button {
                appState.pickFileWithPanel()
            } label: {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                            .fill(Color.accentColor.opacity(0.10))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }

                    VStack(spacing: 4) {
                        Text("拖入本地文档，或点击选择文件")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("毫秒级离线秒开 · 全文关键词检索 · 矢量 PDF 与高清 PNG 导出")
                            .font(ThemeTypography.bodySecondary)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: ThemeRadius.large, style: .continuous)
                        .fill(ThemeColor.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeRadius.large, style: .continuous)
                        .strokeBorder(
                            isHeroHovered ? ThemeColor.elevatedBorder : ThemeColor.subtleBorder,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(isHeroHovered ? 0.10 : 0.04),
                    radius: isHeroHovered ? 12 : 4,
                    x: 0,
                    y: isHeroHovered ? 5 : 2
                )
                .contentShape(RoundedRectangle(cornerRadius: ThemeRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHeroHovered = hovering
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var emptyFilterState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))

            Text("未找到匹配的最近文档")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Text("尝试更换搜索关键词或切换格式筛选器，也可以直接将本地文件拖入窗口预览。")
                .font(ThemeTypography.bodySecondary)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    recentStore.searchQuery = ""
                    recentStore.selectedFormatFilter = nil
                }
            } label: {
                Text("重置筛选条件")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: ThemeRadius.card, style: .continuous)
                .fill(ThemeColor.cardBackground.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ThemeRadius.card, style: .continuous)
                .strokeBorder(ThemeColor.subtleBorder, lineWidth: 1)
        )
    }
}
