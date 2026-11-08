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

/// 定位内置演示样例文件（复用同级 JZOfficeAndroid 仓库中的综合样例）
public enum SampleLocator {
    public static let sampleItems: [(title: String, subtitle: String, fileName: String, kind: OfficeKind)] = [
        ("DOCX 综合演示文档", "段落样式、页眉页脚、自动编号、表格与内嵌图片", "sample.docx", .docx),
        ("PPTX 综合演示幻灯片", "组合图形、自定义几何路径、线性渐变与柱状图", "sample.pptx", .pptx),
        ("XLSX 综合演示工作簿", "多工作表、数字格式化、合并单元格与调色板样式", "sample.xlsx", .xlsx)
    ]

    public static func resolveSampleURL(named fileName: String) -> URL? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        let candidates = [
            cwd.appendingPathComponent("../JZOfficeAndroid/demo/src/main/assets/samples/\(fileName)"),
            cwd.appendingPathComponent("demo/src/main/assets/samples/\(fileName)"),
            bundleParent.appendingPathComponent("../JZOfficeAndroid/demo/src/main/assets/samples/\(fileName)"),
            bundleParent.appendingPathComponent("../../JZOfficeAndroid/demo/src/main/assets/samples/\(fileName)"),
            URL(fileURLWithPath: "/Users/donglua/proj/opensource/JZOfficeAndroid/demo/src/main/assets/samples/\(fileName)")
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.standardizedFileURL
        }
        return nil
    }
}
