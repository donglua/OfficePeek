import Testing
import Foundation
import AppKit
import JZOffice
@testable import OfficePeek
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

    @Test("AppState.presentSearch 触发检索面板并在后台预热全文索引（含 DOCX 浮动形状文本）")
    @MainActor
    func presentSearchPrewarmsIndexAndCoversFloatingDocxText() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-prewarm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let docxURL = tempDir.appendingPathComponent("floating.docx")
        try TestFixtures.writeMinimalFloatingDOCX(to: docxURL)

        let store = RecentFilesStore(storageURL: tempDir.appendingPathComponent("recent.json"))
        let appState = AppState(recentStore: store)
        appState.openDocument(at: docxURL)

        appState.presentSearch()
        #expect(appState.previewController.isSearchPresented)
        await appState.searchPrewarmTask?.value
        #expect(appState.prewarmedSearchPath == docxURL.standardizedFileURL.path)

        let shapeMatches = try await NativeCore.searchDocumentAsync(at: docxURL.path, query: "FloatingShapeKeyword")
        let bodyMatches = try await NativeCore.searchDocumentAsync(at: docxURL.path, query: "BodyParagraphKeyword")
        #expect(!shapeMatches.isEmpty)
        #expect(!bodyMatches.isEmpty)

        appState.closeDocument()
        #expect(!appState.previewController.isSearchPresented)
        #expect(appState.prewarmedSearchPath == nil)
    }

    @Test("PageThumbnailCache 与 OfficePageRenderer 准确渲染第 2 页 PPTX 缩略图与导出第 2 页 PNG/XLSX 工作表")
    @MainActor
    func multiPageThumbnailAndPngExportBypassFirstViewportTruncation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-multipage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pptxURL = tempDir.appendingPathComponent("two_slides.pptx")
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "FF0000", title: "Slide 1"),
            (backgroundHex: "00FF00", title: "Slide 2")
        ])
        NativeCore.evictCache(at: pptxURL.path)

        let cache = PageThumbnailCache()
        let task1 = cache.loadPageThumbnail(from: pptxURL, pageNumber: 1)
        let task2 = cache.loadPageThumbnail(from: pptxURL, pageNumber: 2)
        await task1?.value
        await task2?.value

        let thumb1 = try #require(cache.pageImages[1])
        let thumb2 = try #require(cache.pageImages[2])
        let rgb1 = try sampleCornerRGB(of: thumb1)
        let rgb2 = try sampleCornerRGB(of: thumb2)
        #expect(rgb1.r > 200 && rgb1.g < 50)
        #expect(rgb2.g > 200 && rgb2.r < 50)

        // 导出第 2 页 PNG（在清空 cache 后仍应准确导出绿色第 2 页）
        NativeCore.evictCache(at: pptxURL.path)
        let outPPTXPNG = tempDir.appendingPathComponent("slide2.png")
        try await OfficePageRenderer.exportPNGAsync(
            from: pptxURL,
            pageNumber: 2,
            maxSize: CGSize(width: 480, height: 480),
            to: outPPTXPNG
        )
        let exportedSlide2 = try #require(NSImage(contentsOf: outPPTXPNG))
        let exportedRGB = try sampleCornerRGB(of: exportedSlide2)
        #expect(exportedRGB.g > 200 && exportedRGB.r < 50)

        // 验证 XLSX 第 2 个工作表导出非空白（避免 FirstViewport 截断后续工作表单元格）
        let xlsxURL = tempDir.appendingPathComponent("two_sheets.xlsx")
        try TestFixtures.writeMinimalXLSX(to: xlsxURL, sheets: [
            (name: "SheetOne", headerText: "FirstSheetTitle"),
            (name: "SheetTwo", headerText: "SecondSheetLongTitleText")
        ])
        NativeCore.evictCache(at: xlsxURL.path)
        let outXlsx1 = tempDir.appendingPathComponent("sheet1.png")
        let outXlsx2 = tempDir.appendingPathComponent("sheet2.png")
        try await OfficePageRenderer.exportPNGAsync(from: xlsxURL, pageNumber: 1, maxSize: CGSize(width: 600, height: 400), to: outXlsx1)
        try await OfficePageRenderer.exportPNGAsync(from: xlsxURL, pageNumber: 2, maxSize: CGSize(width: 600, height: 400), to: outXlsx2)
        let sheet1Data = try Data(contentsOf: outXlsx1)
        let sheet2Data = try Data(contentsOf: outXlsx2)
        #expect(!sheet1Data.isEmpty && !sheet2Data.isEmpty)
        #expect(sheet1Data != sheet2Data)

        // 验证含浮动形状与文字环绕的 DOCX 导出 PNG 正常生成非空图像
        let docxURL = tempDir.appendingPathComponent("floating.docx")
        try TestFixtures.writeMinimalFloatingDOCX(to: docxURL)
        let outDocxPNG = tempDir.appendingPathComponent("floating-docx.png")
        try await OfficePageRenderer.exportPNGAsync(from: docxURL, pageNumber: 1, maxSize: CGSize(width: 600, height: 800), to: outDocxPNG)
        let exportedDocx = try #require(NSImage(contentsOf: outDocxPNG))
        #expect(exportedDocx.size.width > 0 && exportedDocx.size.height > 0)
    }

    @Test("对齐 JZOffice v0.15.0：XLSX 冻结窗格解析、渲染导出与全文检索")
    @MainActor
    func xlsxFrozenPanesIntegration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-frozen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xlsxURL = tempDir.appendingPathComponent("frozen.xlsx")
        try TestFixtures.writeFrozenXLSX(to: xlsxURL, sheetName: "Sales", frozenRows: 1, frozenColumns: 1)

        let doc = try NativeCore.parseDocument(at: xlsxURL.path)
        let sheet = try #require(doc.sheets.first)
        #expect(sheet.frozenRows == 1)
        #expect(sheet.frozenColumns == 1)

        let store = RecentFilesStore(storageURL: tempDir.appendingPathComponent("recent.json"))
        let record = await store.recordOpened(url: xlsxURL)
        #expect(record?.format == .xlsx)
        #expect(record?.sheetNames == ["Sales"])
        #expect(store.thumbnails[xlsxURL.standardizedFileURL.path] != nil)

        let outPNG = tempDir.appendingPathComponent("frozen.png")
        try await OfficePageRenderer.exportPNGAsync(
            from: xlsxURL,
            pageNumber: 1,
            maxSize: CGSize(width: 800, height: 600),
            to: outPNG
        )
        let exported = try #require(NSImage(contentsOf: outPNG))
        #expect(exported.size.width > 0 && exported.size.height > 0)

        let frozenMatches = try await NativeCore.searchDocumentAsync(at: xlsxURL.path, query: "FrozenCornerKey")
        let bodyMatches = try await NativeCore.searchDocumentAsync(at: xlsxURL.path, query: "ScrollableBodyKey")
        #expect(!frozenMatches.isEmpty)
        #expect(!bodyMatches.isEmpty)
    }

    @Test("对齐 JZOffice v0.15.0：DOCX 行内图片水平对齐与 spAutoFit 不换行文本框")
    func docxInlineAlignmentAndAutofitTextboxIntegration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-docx-align-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let docxURL = tempDir.appendingPathComponent("inline_autofit.docx")
        try TestFixtures.writeInlineAlignedAndAutofitDOCX(to: docxURL)

        let doc = try NativeCore.parseDocument(at: docxURL.path)
        #expect(doc.blocks.count == 2)
        #expect(doc.blocks[0].type == .image)
        #expect(doc.blocks[0].horizontalAlign == 2)
        #expect(doc.blocks[1].type == .text)
        #expect(!doc.blocks[1].textWrap)

        let outPNG = tempDir.appendingPathComponent("inline_autofit.png")
        try await OfficePageRenderer.exportPNGAsync(
            from: docxURL,
            pageNumber: 1,
            maxSize: CGSize(width: 600, height: 800),
            to: outPNG
        )
        let exported = try #require(NSImage(contentsOf: outPNG))
        #expect(exported.size.width > 0 && exported.size.height > 0)

        let matches = try await NativeCore.searchDocumentAsync(at: docxURL.path, query: "AutofitTextboxKeyword")
        #expect(!matches.isEmpty)
    }

    @Test("对齐 JZOfficeKit v0.16.0：XLSX 单元格与区域选择、合并闭包、冻结窗格与 TSV 导出")
    @MainActor
    func xlsxSelectionAndTsvExportIntegration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-xlsx-sel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xlsxURL = tempDir.appendingPathComponent("selectable.xlsx")
        try TestFixtures.writeSelectableXLSX(to: xlsxURL)

        let doc = try NativeCore.parseDocument(at: xlsxURL.path)
        let sheet = try #require(doc.sheets.first)
        #expect(doc.sheets.count == 2)
        #expect(sheet.frozenRows == 1)
        #expect(sheet.frozenColumns == 1)
        #expect(sheet.merges.count == 1)

        let layout = SheetSelectionModel.SheetSelectionLayout(
            sheet: sheet,
            headerWidth: CGElementDrawer.sheetHeaderWidth,
            headerHeight: CGElementDrawer.sheetHeaderHeight
        )

        // 点击合并区域内的任意一格（B2 -> row 1, col 1），自动闭包扩张为 A2:B2，并视为逻辑单格输出裸文本
        let singleMerged = try #require(SheetSelectionModel.resolve(
            sheet: sheet,
            anchor: SheetSelectionModel.CellCoord(row: 1, column: 1),
            focus: SheetSelectionModel.CellCoord(row: 1, column: 1)
        ))
        #expect(singleMerged.startRow == 1 && singleMerged.endRow == 1)
        #expect(singleMerged.startColumn == 0 && singleMerged.endColumn == 1)
        #expect(SheetSelectionModel.selectedText(sheet: sheet, layout: layout, selection: singleMerged) == "Merged \"North\"")

        // 全选整个工作表可见数据区，验证 TSV 结构与 RFC 4180 引号转义
        let allSel = try #require(SheetSelectionModel.allRange(sheet: sheet, layout: layout))
        let tsv = SheetSelectionModel.selectedText(sheet: sheet, layout: layout, selection: allSel)
        #expect(tsv == "Region\tQ1\tQ2\n\"Merged \"\"North\"\"\"\t\t120\nSouth\t80\t95")

        // 控制器未挂载画布时选区 API 安全降级，且 AppState 开闭文档清理状态不崩溃
        let store = RecentFilesStore(storageURL: tempDir.appendingPathComponent("recent.json"))
        let appState = AppState(recentStore: store)
        appState.openDocument(at: xlsxURL)
        #expect(appState.previewController.hasSelection() == false)
        appState.closeDocument()
        #expect(appState.previewController.getSelectedText() == "")
    }

    @Test("对齐 JZOfficeKit v0.16.0：DOCX 表格单元格边框、背景底纹与垂直对齐")
    func docxStyledTableIntegration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-docx-table-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let docxURL = tempDir.appendingPathComponent("styled_table.docx")
        try TestFixtures.writeStyledTableDOCX(to: docxURL)

        let doc = try NativeCore.parseDocument(at: docxURL.path)
        let table = try #require(doc.blocks.first(where: { $0.type == .table }))
        #expect(table.cellFills == [[0xFFFFCC00, 0xFFDAE8FC]])
        #expect(table.cellValigns == [[0, 2]])
        #expect(table.cellBorders.count == 1 && table.cellBorders[0].count == 2)
        // 第一个单元格上边框为红色 2pt (16/8)，第二个单元格上边框显式为 none (width == 0)
        #expect(table.cellBorders[0][0][0].color == 0xFFCC0000)
        #expect(table.cellBorders[0][0][0].width > 0)
        #expect(table.cellBorders[0][1][0].width == 0)

        let outPNG = tempDir.appendingPathComponent("styled_table.png")
        try await OfficePageRenderer.exportPNGAsync(
            from: docxURL,
            pageNumber: 1,
            maxSize: CGSize(width: 600, height: 800),
            to: outPNG
        )
        let exported = try #require(NSImage(contentsOf: outPNG))
        #expect(exported.size.width > 0 && exported.size.height > 0)
    }

    @Test("对齐 JZOfficeKit v0.16.0：PPTX 饼图、预设几何、虚线描边与连接线箭头")
    func pptxChartsAndDashedGeometryIntegration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-pptx-charts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pptxURL = tempDir.appendingPathComponent("charts_geometry.pptx")
        try TestFixtures.writeChartsAndDashedGeometryPPTX(to: pptxURL)

        let doc = try NativeCore.parseDocument(at: pptxURL.path)
        let page = try #require(doc.pages.first)
        // 验证存在虚线描边元素（star5 / connector）、多子路径连接线箭头以及饼图路径扇区
        let hasDashedStroke = page.elements.contains { !$0.strokeDash.isEmpty }
        let hasDashedConnectorArrow = page.elements.contains {
            $0.type == .path && $0.paths.count >= 2 && !$0.strokeDash.isEmpty
        }
        let pieFillColor: UInt32 = 0xFFE53935
        let hasPieSector = page.elements.contains {
            $0.type == .path && $0.fill == pieFillColor
        }
        #expect(hasDashedStroke)
        #expect(hasDashedConnectorArrow)
        #expect(hasPieSector)

        let outPNG = tempDir.appendingPathComponent("charts_geometry.png")
        try await OfficePageRenderer.exportPNGAsync(
            from: pptxURL,
            pageNumber: 1,
            maxSize: CGSize(width: 800, height: 450),
            to: outPNG
        )
        let exported = try #require(NSImage(contentsOf: outPNG))
        #expect(exported.size.width > 0 && exported.size.height > 0)
    }

    @Test("冷启动按需懒加载缩略图、磁盘缓存命中、修改失效及格式计数缓存")
    @MainActor
    func lazyStartupDiskThumbnailCacheAndDeduplication() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-thumb-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageURL = tempDir.appendingPathComponent("recent.json")
        let cacheDir = tempDir.appendingPathComponent("thumb_cache", isDirectory: true)

        let pptxURL = tempDir.appendingPathComponent("cached_deck.pptx")
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "FF0000", title: "Cached Slide")
        ])

        let store1 = RecentFilesStore(storageURL: storageURL, thumbnailCacheDirectory: cacheDir)
        let record = try #require(await store1.recordOpened(url: pptxURL))
        #expect(store1.pptxCount == 1)
        #expect(store1.docxCount == 0)
        #expect(store1.xlsxCount == 0)

        let cachedFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        #expect(cachedFiles.count == 1)
        #expect(cachedFiles.first?.pathExtension == "png")

        // 模拟冷启动：AppState 初始化不应在启动阶段立即全量生成缩略图
        let store2 = RecentFilesStore(storageURL: storageURL, thumbnailCacheDirectory: cacheDir)
        _ = AppState(recentStore: store2)
        #expect(store2.thumbnails.isEmpty)
        #expect(store2.pptxCount == 1)
        #expect(store2.filteredRecords.count == 1)

        // 并发重复请求同一记录缩略图时应去重并从磁盘缓存命中红色封面
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    await store2.loadThumbnailIfNeeded(for: record)
                }
            }
        }
        let reloadedThumb = try #require(store2.thumbnails[record.id])
        let redPixel = try sampleCornerRGB(of: reloadedThumb)
        #expect(redPixel.r > 200 && redPixel.b < 50)

        // 修改原文件内容后，磁盘缓存 key 应自动失效并重新渲染为蓝色封面
        try await Task.sleep(nanoseconds: 20_000_000)
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "0000FF", title: "Modified Slide")
        ])
        let store3 = RecentFilesStore(storageURL: storageURL, thumbnailCacheDirectory: cacheDir)
        await store3.loadThumbnailIfNeeded(for: record)
        let updatedThumb = try #require(store3.thumbnails[record.id])
        let bluePixel = try sampleCornerRGB(of: updatedThumb)
        #expect(bluePixel.b > 200 && bluePixel.r < 50)

        // 移除记录时应一并清理内存与计数
        store3.remove(id: record.id)
        #expect(store3.pptxCount == 0)
        #expect(store3.filteredRecords.isEmpty)
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
