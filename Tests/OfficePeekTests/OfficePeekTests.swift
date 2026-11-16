import Testing
import Foundation
import AppKit
import JZOffice
@testable import OfficePeekKit

struct OfficePeekTests {

    @Test("RecentFilesStore 登记、持久化、置顶排序、格式过滤与缺失清理")
    @MainActor
    func recentFilesStoreLifecycle() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("recent.json")
        let store = RecentFilesStore(storageURL: storageURL)

        let docxURL = tempDir.appendingPathComponent("document.docx")
        let pptxURL = tempDir.appendingPathComponent("presentation.pptx")
        let xlsxURL = tempDir.appendingPathComponent("spreadsheet.xlsx")
        try "docx".write(to: docxURL, atomically: true, encoding: .utf8)
        try "pptx".write(to: pptxURL, atomically: true, encoding: .utf8)
        try "xlsx".write(to: xlsxURL, atomically: true, encoding: .utf8)

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let r1 = RecentFileRecord(
            path: docxURL.path,
            displayName: "document.docx",
            format: .docx,
            pageCount: 1,
            sheetNames: [],
            fileSizeBytes: 1024,
            lastOpenedAt: t0
        )
        let r2 = RecentFileRecord(
            path: pptxURL.path,
            displayName: "presentation.pptx",
            format: .pptx,
            pageCount: 5,
            sheetNames: [],
            fileSizeBytes: 2048,
            lastOpenedAt: t0.addingTimeInterval(10)
        )
        let r3 = RecentFileRecord(
            path: xlsxURL.path,
            displayName: "spreadsheet.xlsx",
            format: .xlsx,
            pageCount: 3,
            sheetNames: ["Sheet1"],
            fileSizeBytes: 4096,
            lastOpenedAt: t0.addingTimeInterval(20)
        )

        store.register(record: r1)
        store.register(record: r2)
        store.register(record: r3)

        #expect(store.records.count == 3)
        #expect(store.filteredRecords.first?.id == r3.id)

        // Pin r1 (document.docx) -> should move to first in filteredRecords
        store.togglePin(for: r1.id)
        #expect(store.filteredRecords.first?.id == r1.id)

        // Filter by PPTX
        store.selectedFormatFilter = .pptx
        #expect(store.filteredRecords.count == 1)
        #expect(store.filteredRecords.first?.id == r2.id)
        store.selectedFormatFilter = nil

        // Search by keyword
        store.searchQuery = "spreadsheet"
        #expect(store.filteredRecords.count == 1)
        #expect(store.filteredRecords.first?.id == r3.id)
        store.searchQuery = ""

        // Reload from disk and verify persistence
        let reloaded = RecentFilesStore(storageURL: storageURL)
        #expect(reloaded.records.count == 3)
        #expect(reloaded.filteredRecords.first?.id == r1.id)

        // Test remove
        reloaded.remove(id: r2.id)
        #expect(reloaded.records.count == 2)

        // Test prune missing files
        try FileManager.default.removeItem(at: docxURL)
        reloaded.pruneMissingFiles()
        #expect(reloaded.records.count == 1)
        #expect(reloaded.filteredRecords.first?.id == r3.id)
    }

    @Test("OfficePreviewController 全文检索状态流转与导航联动")
    @MainActor
    func searchStateLifecycle() {
        let controller = OfficePreviewController()
        #expect(!controller.isSearchPresented)
        #expect(controller.searchResults.isEmpty)
        #expect(!controller.isSearching)

        // 呼出检索面板
        controller.presentSearch()
        #expect(controller.isSearchPresented)

        // 关闭检索面板并清除结果
        controller.dismissSearch()
        #expect(!controller.isSearchPresented)
        #expect(controller.searchResults.isEmpty)
        #expect(controller.searchQuery.isEmpty)
    }

    @Test("RecentFilesStore 异步读取轻量元数据并在文档变更重开时刷新记录与封面")
    @MainActor
    func asyncMetadataAndThumbnailRefreshOnReopen() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-async-meta-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pptxURL = tempDir.appendingPathComponent("deck.pptx")
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "FF0000", title: "Slide One"),
            (backgroundHex: "00FF00", title: "Slide Two")
        ])

        let store = RecentFilesStore(storageURL: tempDir.appendingPathComponent("recent.json"))
        let firstRecord = await store.recordOpened(url: pptxURL)
        #expect(firstRecord?.format == .pptx)
        #expect(firstRecord?.pageCount == 2)
        let firstThumb = try #require(store.thumbnails[pptxURL.standardizedFileURL.path])
        let firstPixel = try sampleCornerRGB(of: firstThumb)
        #expect(firstPixel.r > 200 && firstPixel.b < 50)

        // 修改原文件内容为 3 页并重新打开，应更新元数据与缩略图
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "0000FF", title: "Updated Slide One"),
            (backgroundHex: "00FF00", title: "Slide Two"),
            (backgroundHex: "EEEEEE", title: "Slide Three")
        ])

        let updatedRecord = await store.recordOpened(url: pptxURL)
        #expect(updatedRecord?.pageCount == 3)
        #expect(store.records.first?.pageCount == 3)
        let updatedThumb = try #require(store.thumbnails[pptxURL.standardizedFileURL.path])
        let updatedPixel = try sampleCornerRGB(of: updatedThumb)
        #expect(updatedPixel.b > 200 && updatedPixel.r < 50)
    }

    private func sampleCornerRGB(of image: NSImage) throws -> (r: UInt8, g: UInt8, b: UInt8) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OfficePeekTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing CGImage"])
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        var full = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        guard let fullCtx = CGContext(
            data: &full,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "OfficePeekTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate bitmap context"])
        }
        fullCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        let offset = (2 * cgImage.width + 2) * 4
        return (full[offset], full[offset + 1], full[offset + 2])
    }
}
