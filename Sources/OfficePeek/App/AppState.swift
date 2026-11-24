import Foundation
import AppKit
import UniformTypeIdentifiers
import JZOffice
import OfficePeekKit

/// OfficePeek 全局应用状态控制器
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var activeFileURL: URL?
    @Published public var isSidebarVisible: Bool = true
    @Published public var showWarningsSheet: Bool = false
    @Published public var toastMessage: String?

    public let recentStore: RecentFilesStore
    public let previewController = OfficePreviewController()
    public let pageThumbnailCache = PageThumbnailCache()

    internal private(set) var searchPrewarmTask: Task<Void, Never>?
    internal private(set) var prewarmedSearchPath: String?
    private var prewarmingSearchPath: String?

    public init(recentStore: RecentFilesStore? = nil) {
        self.recentStore = recentStore ?? RecentFilesStore()
    }

    public func openDocument(at url: URL) {
        let stdURL = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: stdURL.path) else {
            showToast("文件不存在：\(stdURL.lastPathComponent)")
            return
        }
        cancelSearchPrewarm()
        previewController.dismissSearch()
        previewController.clearSelection()
        pageThumbnailCache.reset(for: stdURL)
        activeFileURL = stdURL
        Task(priority: .utility) {
            await recentStore.recordOpened(url: stdURL)
        }
    }

    public func closeDocument() {
        cancelSearchPrewarm()
        previewController.dismissSearch()
        previewController.clearSelection()
        pageThumbnailCache.clear()
        activeFileURL = nil
        showWarningsSheet = false
    }

    /// 打开全文检索栏并在后台按需预热当前文档的检索索引
    public func presentSearch() {
        previewController.presentSearch()
        guard let path = activeFileURL?.standardizedFileURL.path,
              prewarmedSearchPath != path,
              prewarmingSearchPath != path else {
            return
        }
        searchPrewarmTask?.cancel()
        prewarmingSearchPath = path
        searchPrewarmTask = Task { @MainActor [weak self] in
            try? await NativeCore.prewarmSearchIndexAsync(at: path)
            guard let self else { return }
            if self.prewarmingSearchPath == path {
                self.prewarmingSearchPath = nil
            }
            guard !Task.isCancelled,
                  self.activeFileURL?.standardizedFileURL.path == path else {
                return
            }
            self.prewarmedSearchPath = path
        }
    }

    private func cancelSearchPrewarm() {
        searchPrewarmTask?.cancel()
        searchPrewarmTask = nil
        prewarmingSearchPath = nil
        prewarmedSearchPath = nil
    }

    public func pickFileWithPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择要预览的 Office 文档"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "docx"),
            UTType(filenameExtension: "pptx"),
            UTType(filenameExtension: "xlsx"),
            UTType.commaSeparatedText,
            UTType.tabSeparatedText
        ].compactMap { $0 }
        if panel.runModal() == .OK, let url = panel.url {
            openDocument(at: url)
        }
    }

    public func exportPDF(for sourceURL: URL? = nil) {
        guard let targetURL = sourceURL ?? activeFileURL else { return }
        let savePanel = NSSavePanel()
        savePanel.title = "导出为矢量 PDF"
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = targetURL.deletingPathExtension().lastPathComponent + ".pdf"
        guard savePanel.runModal() == .OK, let outURL = savePanel.url else { return }

        Task {
            do {
                try await OfficeExporter.exportPDFAsync(from: targetURL, to: outURL)
                showToast("已导出 PDF：\(outURL.lastPathComponent)")
                NSWorkspace.shared.activateFileViewerSelecting([outURL])
            } catch {
                showToast("导出 PDF 失败：\(error.localizedDescription)")
            }
        }
    }

    public func exportCurrentPagePNG() {
        guard let targetURL = activeFileURL else { return }
        let page = max(1, previewController.currentPage)
        let savePanel = NSSavePanel()
        savePanel.title = "导出当前页为高清 PNG"
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(targetURL.deletingPathExtension().lastPathComponent)-p\(page).png"
        guard savePanel.runModal() == .OK, let outURL = savePanel.url else { return }

        Task {
            do {
                try await OfficePageRenderer.exportPNGAsync(
                    from: targetURL,
                    pageNumber: page,
                    maxSize: CGSize(width: 2400, height: 2400),
                    to: outURL
                )
                showToast("已导出 PNG：\(outURL.lastPathComponent)")
                NSWorkspace.shared.activateFileViewerSelecting([outURL])
            } catch {
                showToast("导出 PNG 失败：\(error.localizedDescription)")
            }
        }
    }

    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func showToast(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.toastMessage == text {
                self.toastMessage = nil
            }
        }
    }
}
