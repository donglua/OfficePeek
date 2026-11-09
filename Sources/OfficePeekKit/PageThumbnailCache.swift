import Foundation
import AppKit
import JZOffice

/// 按页缩略图异步缓存（用于 PPTX 侧边栏幻灯片缩略图栏与 XLSX 工作表预览）
@MainActor
public final class PageThumbnailCache: ObservableObject {
    @Published public private(set) var pageImages: [Int: NSImage] = [:]
    private var currentFilePath: String = ""

    public init() {}

    public func reset(for url: URL) {
        let stdPath = url.standardizedFileURL.path
        if currentFilePath != stdPath {
            currentFilePath = stdPath
            pageImages.removeAll()
        }
    }

    public func loadPageThumbnail(from url: URL, pageNumber: Int, maxSize: CGSize = CGSize(width: 220, height: 140)) {
        let stdURL = url.standardizedFileURL
        reset(for: stdURL)
        guard pageImages[pageNumber] == nil else { return }
        let expectedPath = stdURL.path
        Task {
            if let img = try? await OfficeThumbnail.renderPageAsync(
                from: stdURL,
                pageNumber: pageNumber,
                maxSize: maxSize
            ) {
                if self.currentFilePath == expectedPath {
                    self.pageImages[pageNumber] = img
                }
            }
        }
    }
}
