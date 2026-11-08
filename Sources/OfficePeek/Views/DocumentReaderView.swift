import SwiftUI
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// 文档阅读器主视图（工具栏 + 可折叠侧边栏 + 主预览画布 + 底部工作表标签栏）
struct DocumentReaderView: View {
    let fileURL: URL
    @ObservedObject var appState: AppState
    @ObservedObject var controller: OfficePreviewController
    @ObservedObject var pageThumbnailCache: PageThumbnailCache

    var body: some View {
        VStack(spacing: 0) {
            readerToolbar
            Divider()

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
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var readerToolbar: some View {
        HStack(spacing: 10) {
            Button {
                appState.closeDocument()
            } label: {
                Text("← 主页")
                    .font(.system(size: 12, weight: .medium))
            }

            Button {
                appState.isSidebarVisible.toggle()
            } label: {
                Text(appState.isSidebarVisible ? "隐藏侧栏" : "显示侧栏")
                    .font(.system(size: 12))
            }

            Divider().frame(height: 18)

            if let kind = controller.metadata?.format {
                FormatBadgeView(kind: kind, compact: true)
            }

            Text(fileURL.lastPathComponent)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)

            Spacer()

            if controller.pageCount > 1 {
                HStack(spacing: 4) {
                    Button("◀") {
                        controller.jumpToPage(max(1, controller.currentPage - 1))
                    }
                    .disabled(controller.currentPage <= 1)

                    Text("\(controller.currentPage) / \(controller.pageCount)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(minWidth: 48)

                    Button("▶") {
                        controller.jumpToPage(min(controller.pageCount, controller.currentPage + 1))
                    }
                    .disabled(controller.currentPage >= controller.pageCount)
                }

                Divider().frame(height: 18)
            }

            HStack(spacing: 4) {
                Button("−") {
                    controller.setZoom(controller.zoom - 0.25)
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button("\(Int(round(controller.zoom * 100)))%") {
                    controller.resetZoom()
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minWidth: 48)
                .keyboardShortcut("0", modifiers: [.command])

                Button("+") {
                    controller.setZoom(controller.zoom + 0.25)
                }
                .keyboardShortcut("=", modifiers: [.command])
            }

            if let warnings = controller.metadata?.warnings, !warnings.isEmpty {
                Divider().frame(height: 18)
                Button {
                    appState.showWarningsSheet = true
                } label: {
                    Text("⚠️ \(warnings.count) 条提示")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }

            Divider().frame(height: 18)

            Menu("导出 / 操作") {
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
            }
            .frame(width: 110)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(nsColor: .windowBackgroundColor))
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
