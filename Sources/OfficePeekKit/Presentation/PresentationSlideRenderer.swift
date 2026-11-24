import Foundation
import CoreGraphics
import JZOffice

/// 演示模式幻灯片渲染器：单次解析文档，按屏幕像素尺寸渲染当前页并预取 ±1 页，
/// 淘汰距当前页超过 `retainRadius` 的位图，控制屏幕级位图常驻数量。
@MainActor
public final class PresentationSlideRenderer: ObservableObject {
    @Published public private(set) var images: [Int: CGImage] = [:]
    @Published public private(set) var failedSlides: Set<Int> = []
    @Published public private(set) var loadError: String?

    public let fileURL: URL
    public let targetPixelSize: CGSize
    public let retainRadius: Int
    public private(set) var focusSlide: Int = 1

    private var documentTask: Task<OfficeDocument, Error>?
    private var renderTasks: [Int: (id: UUID, task: Task<Void, Never>)] = [:]

    public init(fileURL: URL, targetPixelSize: CGSize, retainRadius: Int = 2) {
        self.fileURL = fileURL.standardizedFileURL
        self.targetPixelSize = targetPixelSize
        self.retainRadius = max(1, retainRadius)
    }

    /// 切换焦点页：优先渲染该页，随后预取下一页与上一页
    public func show(slide: Int) {
        guard slide >= 1 else { return }
        focusSlide = slide
        evictOutsideWindow()
        for target in [slide, slide + 1, slide - 1] where target >= 1 {
            render(target)
        }
    }

    /// 等待当前所有渲染任务结束（测试与退出前收尾使用）
    public func waitUntilIdle() async {
        while let entry = renderTasks.values.first {
            await entry.task.value
        }
    }

    /// 取消全部渲染任务（退出演示时调用）
    public func cancelAll() {
        for entry in renderTasks.values {
            entry.task.cancel()
        }
        renderTasks.removeAll()
        documentTask = nil
    }

    private func isInWindow(_ slide: Int) -> Bool {
        abs(slide - focusSlide) <= retainRadius
    }

    private func evictOutsideWindow() {
        for key in Array(images.keys) where !isInWindow(key) {
            images.removeValue(forKey: key)
        }
        for key in Array(renderTasks.keys) where !isInWindow(key) {
            renderTasks[key]?.task.cancel()
            renderTasks.removeValue(forKey: key)
        }
    }

    private func render(_ slide: Int) {
        guard images[slide] == nil,
              renderTasks[slide] == nil,
              !failedSlides.contains(slide),
              loadError == nil else {
            return
        }
        let path = fileURL.path
        let maxSize = targetPixelSize
        let parseTask = sharedDocumentTask(path: path)
        let id = UUID()

        let task = Task { [weak self] in
            defer {
                if let self, self.renderTasks[slide]?.id == id {
                    self.renderTasks.removeValue(forKey: slide)
                }
            }
            let document: OfficeDocument
            do {
                document = try await parseTask.value
            } catch {
                self?.loadError = error.localizedDescription
                return
            }
            guard let self, !Task.isCancelled else { return }
            if document.pages.isEmpty {
                self.loadError = "演示文稿不包含任何幻灯片"
                return
            }
            guard slide <= document.pages.count else { return }
            do {
                let image = try await Task.detached(priority: .userInitiated) {
                    try OfficePageRenderer.renderPageCGImage(
                        document: document,
                        filePath: path,
                        pageNumber: slide,
                        maxSize: maxSize
                    )
                }.value
                guard !Task.isCancelled, self.isInWindow(slide) else { return }
                self.images[slide] = image
            } catch {
                guard !Task.isCancelled else { return }
                self.failedSlides.insert(slide)
            }
        }
        renderTasks[slide] = (id: id, task: task)
    }

    private func sharedDocumentTask(path: String) -> Task<OfficeDocument, Error> {
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
