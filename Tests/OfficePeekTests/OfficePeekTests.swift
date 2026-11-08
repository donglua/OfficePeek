import Testing
import Foundation
import JZOffice
@testable import OfficePeekKit

struct OfficePeekTests {

    @Test("SampleLocator 能定位内置 DOCX / PPTX / XLSX 综合样例")
    func sampleLocatorResolvesSamples() {
        for item in SampleLocator.sampleItems {
            let url = SampleLocator.resolveSampleURL(named: item.fileName)
            #expect(url != nil, "Should resolve \(item.fileName)")
        }
    }

    @Test("RecentFilesStore 登记、持久化、置顶排序与按格式过滤")
    @MainActor
    func recentFilesStoreLifecycle() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("recent.json")
        let store = RecentFilesStore(storageURL: storageURL)

        guard let docxURL = SampleLocator.resolveSampleURL(named: "sample.docx"),
              let pptxURL = SampleLocator.resolveSampleURL(named: "sample.pptx"),
              let xlsxURL = SampleLocator.resolveSampleURL(named: "sample.xlsx") else {
            return
        }

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let r1 = try store.recordOpenedSync(url: docxURL, now: t0)
        let r2 = try store.recordOpenedSync(url: pptxURL, now: t0.addingTimeInterval(10))
        let r3 = try store.recordOpenedSync(url: xlsxURL, now: t0.addingTimeInterval(20))

        #expect(store.records.count == 3)
        #expect(store.filteredRecords.first?.id == r3.id)

        // Pin r1 (sample.docx) -> should move to first in filteredRecords
        store.togglePin(for: r1.id)
        #expect(store.filteredRecords.first?.id == r1.id)

        // Filter by PPTX
        store.selectedFormatFilter = .pptx
        #expect(store.filteredRecords.count == 1)
        #expect(store.filteredRecords.first?.id == r2.id)
        store.selectedFormatFilter = nil

        // Search by keyword
        store.searchQuery = "xlsx"
        #expect(store.filteredRecords.count == 1)
        #expect(store.filteredRecords.first?.id == r3.id)
        store.searchQuery = ""

        // Reload from disk and verify persistence
        let reloaded = RecentFilesStore(storageURL: storageURL)
        #expect(reloaded.records.count == 3)
        #expect(reloaded.filteredRecords.first?.id == r1.id)

        reloaded.remove(id: r2.id)
        #expect(reloaded.records.count == 2)
    }
}
