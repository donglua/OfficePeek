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

    public init(recentStore: RecentFilesStore? = nil) {
        self.recentStore = recentStore ?? RecentFilesStore()
        self.recentStore.refreshThumbnails()
    }

    public func openDocument(at url: URL) {
        let stdURL = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: stdURL.path) else {
            showToast("文件不存在：\(stdURL.lastPathComponent)")
            return
        }
        previewController.dismissSearch()
        pageThumbnailCache.reset(for: stdURL)
        activeFileURL = stdURL
        Task {
            await recentStore.recordOpened(url: stdURL)
        }
    }

    public func closeDocument() {
        previewController.dismissSearch()
        activeFileURL = nil
        showWarningsSheet = false
    }

    public func pickFileWithPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择要预览的 Office 文档"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "docx"),
            UTType(filenameExtension: "pptx"),
            UTType(filenameExtension: "xlsx")
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
                try await OfficeExporter.exportPNGAsync(
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
