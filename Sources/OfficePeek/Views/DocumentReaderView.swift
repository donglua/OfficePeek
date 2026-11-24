import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 文档阅读器主视图（系统级工具栏 + 可折叠侧边栏 + 主预览画布 + 底部工作表标签栏 + 全窗拖拽切换）
struct DocumentReaderView: View {
    let fileURL: URL
    @ObservedObject var appState: AppState
    @ObservedObject var controller: OfficePreviewController
    @ObservedObject var pageThumbnailCache: PageThumbnailCache

    private typealias ViewState = SwiftUI.State
    @ViewState private var isDragTargeted = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if appState.isSidebarVisible {
                    DocumentSidebarView(
                        fileURL: fileURL,
                        controller: controller,
                        pageThumbnailCache: pageThumbnailCache
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle()
                        .fill(ThemeColor.hairlineSeparator)
                        .frame(width: 1)
                }

                VStack(spacing: 0) {
                    OfficePreviewView(
                        fileURL: fileURL,
                        controller: controller
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    OfficeSheetTabs(controller: controller)
                }
            }
            .background(ThemeColor.canvasBackground)

            DropOverlayView(isTargeted: isDragTargeted)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    appState.closeDocument()
                } label: {
                    Label("返回主页", systemImage: "chevron.backward")
                }
                .help("返回欢迎主页 (⌘W)")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isSidebarVisible.toggle()
                    }
                } label: {
                    Label(appState.isSidebarVisible ? "隐藏侧栏" : "显示侧栏", systemImage: "sidebar.left")
                }
                .help("显示/隐藏侧边栏 (⌘\\)")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    if let kind = controller.metadata?.format {
                        FormatBadgeView(
                            kind: kind,
                            label: FormatBadgeView.badgeLabel(for: kind, fileURL: fileURL),
                            compact: true
                        )
                    }
                    Text(fileURL.lastPathComponent)
                        .font(ThemeTypography.windowTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 6)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if controller.pageCount > 1 {
                    ControlGroup {
                        Button {
                            controller.jumpToPage(max(1, controller.currentPage - 1))
                        } label: {
                            Label("上一页", systemImage: "chevron.left")
                        }
                        .disabled(controller.currentPage <= 1)
                        .help("上一页")

                        Text("\(controller.currentPage) / \(controller.pageCount)")
                            .font(ThemeTypography.monospacedValue)
                            .monospacedDigit()
                            .frame(minWidth: 50)

                        Button {
                            controller.jumpToPage(min(controller.pageCount, controller.currentPage + 1))
                        } label: {
                            Label("下一页", systemImage: "chevron.right")
                        }
                        .disabled(controller.currentPage >= controller.pageCount)
                        .help("下一页")
                    }
                }

                ControlGroup {
                    Button {
                        controller.setZoom(controller.zoom - 0.25)
                    } label: {
                        Label("缩小", systemImage: "minus")
                    }
                    .keyboardShortcut("-", modifiers: [.command])
                    .help("缩小 (⌘-)")

                    Button {
                        controller.resetZoom()
                    } label: {
                        Text("\(Int(round(controller.zoom * 100)))%")
                            .font(ThemeTypography.monospacedValue)
                            .monospacedDigit()
                            .frame(minWidth: 46)
                    }
                    .keyboardShortcut("0", modifiers: [.command])
                    .help("恢复 100% (⌘0)")

                    Button {
                        controller.setZoom(controller.zoom + 0.25)
                    } label: {
                        Label("放大", systemImage: "plus")
                    }
                    .keyboardShortcut("=", modifiers: [.command])
                    .help("放大 (⌘=)")
                }

                Button {
                    if controller.isSearchPresented {
                        controller.dismissSearch()
                    } else {
                        appState.presentSearch()
                    }
                } label: {
                    Label("查找", systemImage: "magnifyingglass")
                }
                .foregroundColor(controller.isSearchPresented ? .accentColor : .primary)
                .keyboardShortcut("f", modifiers: [.command])
                .help("全文检索 (⌘F)")

                if let warnings = controller.metadata?.warnings, !warnings.isEmpty {
                    Button {
                        appState.showWarningsSheet = true
                    } label: {
                        Label("\(warnings.count) 条提示", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    .help("查看文档兼容性提示")
                }

                Menu {
                    Button("导出为矢量 PDF…") {
                        appState.exportPDF(for: fileURL)
                    }
                    .keyboardShortcut("e", modifiers: [.command])

                    Button("导出当前页为高清 PNG…") {
                        appState.exportCurrentPagePNG()
                    }

                    Divider()

                    Button("在 Finder 中显示") {
                        appState.revealInFinder(fileURL)
                    }

                    Button("打开其他文档…") {
                        appState.pickFileWithPanel()
                    }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .help("导出或更多操作")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            DropOverlayView.extractFirstFileURL(from: providers) { url in
                appState.openDocument(at: url)
            }
        }
        .sheet(isPresented: $appState.showWarningsSheet) {
            warningsDialog
        }
    }

    private var warningsDialog: some View {
        let warnings = controller.metadata?.warnings ?? []
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("文档兼容性提示 (\(warnings.count))")
                        .font(.system(size: 15, weight: .semibold))
                    Text("以下元素已按最优兼容策略降级渲染，不影响正文阅读。")
                        .font(ThemeTypography.bodySecondary)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { idx, msg in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(format: "%02d", idx + 1))
                                .font(ThemeTypography.monospacedValue)
                                .foregroundColor(.secondary)
                                .padding(.top, 1)

                            Text(msg)
                                .font(.system(size: 12.5))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                                .fill(ThemeColor.thumbnailStageBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                                .strokeBorder(ThemeColor.hairlineSeparator, lineWidth: 0.75)
                        )
                    }
                }
            }
            .frame(minHeight: 160, maxHeight: 280)

            HStack {
                Spacer()
                Button("完成") {
                    appState.showWarningsSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 470)
    }
}
