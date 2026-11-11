import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 文档阅读器主视图（系统级工具栏 + 可折叠侧边栏 + 主预览画布 + 底部工作表标签栏）
struct DocumentReaderView: View {
    let fileURL: URL
    @ObservedObject var appState: AppState
    @ObservedObject var controller: OfficePreviewController
    @ObservedObject var pageThumbnailCache: PageThumbnailCache

    var body: some View {
        HStack(spacing: 0) {
            if appState.isSidebarVisible {
                DocumentSidebarView(
                    fileURL: fileURL,
                    controller: controller,
                    pageThumbnailCache: pageThumbnailCache
                )
                Divider()
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
        .background(Color(nsColor: .underPageBackgroundColor))
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
                HStack(spacing: 6) {
                    if let kind = controller.metadata?.format {
                        FormatBadgeView(kind: kind, compact: true)
                    }
                    Text(fileURL.lastPathComponent)
                        .font(ThemeTypography.windowTitle)
                        .lineLimit(1)
                }
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
                            .frame(minWidth: 48)

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
                            .frame(minWidth: 44)
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
                        controller.presentSearch()
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
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
        .sheet(isPresented: $appState.showWarningsSheet) {
            warningsDialog
        }
    }

    private var warningsDialog: some View {
        let warnings = controller.metadata?.warnings ?? []
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("文档兼容性提示 (\(warnings.count))")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("关闭") {
                    appState.showWarningsSheet = false
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { idx, msg in
                        Text("\(idx + 1). \(msg)")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 160, maxHeight: 280)
        }
        .padding(20)
        .frame(width: 460)
    }
}
