import Foundation
import AppKit
import JZOffice

/// 按页缩略图异步缓存（用于 PPTX 侧边栏幻灯片缩略图栏）
@MainActor
public final class PageThumbnailCache: ObservableObject {
    @Published public private(set) var pageImages: [Int: NSImage] = [:]
    private var currentFilePath: String = ""
    private var documentTask: Task<OfficeDocument, Error>?
    private var pageTasks: [Int: Task<Void, Never>] = [:]

    public init() {}

    public func reset(for url: URL) {
        let stdPath = url.standardizedFileURL.path
        if currentFilePath != stdPath {
            clear(forPath: stdPath)
        }
    }

    public func clear() {
        clear(forPath: "")
    }

    private func clear(forPath newPath: String) {
        documentTask?.cancel()
        documentTask = nil
        for task in pageTasks.values {
            task.cancel()
        }
        pageTasks.removeAll()
        pageImages.removeAll()
        currentFilePath = newPath
    }

    @discardableResult
    public func loadPageThumbnail(
        from url: URL,
        pageNumber: Int,
        maxSize: CGSize = CGSize(width: 220, height: 140)
    ) -> Task<Void, Never>? {
        let stdURL = url.standardizedFileURL
        reset(for: stdURL)
        if pageImages[pageNumber] != nil { return nil }
        if let existing = pageTasks[pageNumber] { return existing }

        let expectedPath = stdURL.path
        let parseTask = sharedDocumentTask(for: expectedPath)
        let task = Task { [weak self] in
            defer {
                if let self, self.currentFilePath == expectedPath {
                    self.pageTasks.removeValue(forKey: pageNumber)
                }
            }
            let doc: OfficeDocument
            do {
                doc = try await parseTask.value
            } catch {
                if self?.documentTask == parseTask {
                    self?.documentTask = nil
                }
                return
            }
            guard !Task.isCancelled else { return }
            let img = try? await Task.detached(priority: .userInitiated) {
                try OfficePageRenderer.renderPageImage(
                    document: doc,
                    filePath: expectedPath,
                    pageNumber: pageNumber,
                    maxSize: maxSize
                )
            }.value
            guard !Task.isCancelled,
                  let self,
                  self.currentFilePath == expectedPath,
                  let img else {
                return
            }
            self.pageImages[pageNumber] = img
        }
        pageTasks[pageNumber] = task
        return task
    }

    private func sharedDocumentTask(for path: String) -> Task<OfficeDocument, Error> {
        if let existing = documentTask {
            return existing
        }
        let task = Task.detached(priority: .userInitiated) {
            try NativeCore.parseDocument(at: path)
        }
        documentTask = task
        return task
    }
}
