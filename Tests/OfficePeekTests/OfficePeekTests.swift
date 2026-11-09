import Testing
import Foundation
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
}
