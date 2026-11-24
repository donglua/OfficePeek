import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import JZOffice

/// 面向已打开文档的按页离屏渲染与 PNG 导出工具（走完整文档解析路径，不触发底层缓存驱逐）
public enum OfficePageRenderer {

    /// 将已解析的 `OfficeDocument` 中指定页码（从 1 开始）渲染为 `NSImage`
    public static func renderPageImage(
        document: OfficeDocument,
        filePath: String,
        pageNumber: Int,
        maxSize: CGSize
    ) throws -> NSImage {
        let cgImage = try renderPageCGImage(
            document: document,
            filePath: filePath,
            pageNumber: pageNumber,
            maxSize: maxSize
        )
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// 将已解析的 `OfficeDocument` 中指定页码（从 1 开始）渲染为 `CGImage`
    public static func renderPageCGImage(
        document: OfficeDocument,
        filePath: String,
        pageNumber: Int,
        maxSize: CGSize
    ) throws -> CGImage {
        guard maxSize.width > 0 && maxSize.height > 0 else {
            throw OfficeError.invalidArguments("Target maxSize must be positive, got \(maxSize.width)x\(maxSize.height)")
        }
        guard pageNumber >= 1 else {
            throw OfficeError.invalidArguments("pageNumber must be >= 1, got \(pageNumber)")
        }

        switch document.kind {
        case .pptx:
            return try renderPptxPage(
                document: document,
                filePath: filePath,
                pageIndex: pageNumber - 1,
                maxSize: maxSize
            )
        case .docx:
            return try renderDocxFirstPage(
                document: document,
                filePath: filePath,
                maxSize: maxSize
            )
        case .xlsx:
            return try renderXlsxSheet(
                document: document,
                filePath: filePath,
                sheetIndex: pageNumber - 1,
                maxSize: maxSize
            )
        }
    }

    /// 同步将指定页面（从 1 开始）导出为 PNG 文件（走完整解析，保证第 2+ 页/工作表完整渲染）
    public static func exportPNG(
        from sourceURL: URL,
        pageNumber: Int = 1,
        maxSize: CGSize = CGSize(width: 1920, height: 1920),
        to destinationURL: URL
    ) throws {
        let path = sourceURL.standardizedFileURL.path
        let doc = try NativeCore.parseDocument(at: path)
        let cgImage = try renderPageCGImage(
            document: doc,
            filePath: path,
            pageNumber: pageNumber,
            maxSize: maxSize
        )
        guard let dest = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw OfficeError.renderFailed("Failed to create PNG destination at \(destinationURL.path)")
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw OfficeError.renderFailed("Failed to finalize PNG write at \(destinationURL.path)")
        }
    }

    /// 异步将指定页面导出为 PNG 文件
    public static func exportPNGAsync(
        from sourceURL: URL,
        pageNumber: Int = 1,
        maxSize: CGSize = CGSize(width: 1920, height: 1920),
        to destinationURL: URL
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try exportPNG(from: sourceURL, pageNumber: pageNumber, maxSize: maxSize, to: destinationURL)
        }.value
    }

    private static func makeTopDownContext(width: Int, height: Int, scale: CGFloat) throws -> CGContext {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw OfficeError.renderFailed("Failed to allocate bitmap context \(width)x\(height)")
        }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)
        return ctx
    }

    private static func renderBitmap(
        logicalSize: CGSize,
        maxSize: CGSize,
        draw: (CGContext) -> Void
    ) throws -> CGImage {
        let scale = min(maxSize.width / logicalSize.width, maxSize.height / logicalSize.height)
        let outW = max(1, Int(round(logicalSize.width * scale)))
        let outH = max(1, Int(round(logicalSize.height * scale)))
        let ctx = try makeTopDownContext(width: outW, height: outH, scale: scale)
        draw(ctx)
        guard let cgImage = ctx.makeImage() else {
            throw OfficeError.renderFailed("Failed to extract CGImage from bitmap context")
        }
        return cgImage
    }

    private static func pixelBudget(logicalSize: CGSize, maxSize: CGSize) -> Int {
        let scale = min(maxSize.width / logicalSize.width, maxSize.height / logicalSize.height)
        let outW = max(1, Int(round(logicalSize.width * scale)))
        let outH = max(1, Int(round(logicalSize.height * scale)))
        return max(100_000, min(2_000_000, outW * outH * 2))
    }

    private static func loadImages(
        parts: [String],
        filePath: String,
        maxPixelBudget: Int
    ) -> [String: CGImage] {
        var result: [String: CGImage] = [:]
        var seen: Set<String> = []
        for part in parts where !part.isEmpty {
            guard seen.insert(part).inserted else { continue }
            guard let data = try? NativeCore.readPart(at: filePath, part: part),
                  !data.isEmpty,
                  let image = ImageStore.decodeCGImage(from: data, maxPixels: maxPixelBudget) else {
                continue
            }
            result[part] = image
        }
        return result
    }

    private static func renderPptxPage(
        document: OfficeDocument,
        filePath: String,
        pageIndex: Int,
        maxSize: CGSize
    ) throws -> CGImage {
        guard !document.pages.isEmpty else {
            throw OfficeError.renderFailed("Presentation has no slides")
        }
        let clampedIndex = max(0, min(document.pages.count - 1, pageIndex))
        let page = document.pages[clampedIndex]
        let slideSize = CGSize(
            width: page.width > 0 ? page.width : 720,
            height: page.height > 0 ? page.height : 405
        )
        let budget = pixelBudget(logicalSize: slideSize, maxSize: maxSize)
        let parts = page.elements.compactMap { $0.type == .image ? $0.image : nil }
        let images = loadImages(parts: parts, filePath: filePath, maxPixelBudget: budget)

        return try renderBitmap(logicalSize: slideSize, maxSize: maxSize) { ctx in
            let bg = CGElementDrawer.argbToCGColor(page.background) ?? CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            ctx.setFillColor(bg)
            ctx.fill(CGRect(origin: .zero, size: slideSize))
            for el in page.elements {
                CGElementDrawer.drawElement(in: ctx, element: el, images: images)
            }
        }
    }

    private static func renderDocxFirstPage(
        document: OfficeDocument,
        filePath: String,
        maxSize: CGSize
    ) throws -> CGImage {
        let docW = document.width > 0 ? document.width : 595
        let docSize = CGSize(width: docW, height: docW * 1.414)
        let budget = pixelBudget(logicalSize: docSize, maxSize: maxSize)

        var parts: [String] = []
        for block in (document.headerBlocks + document.blocks + document.footerBlocks) {
            if block.type == .image, let part = block.image {
                parts.append(part)
            } else if block.type == .table {
                for row in block.rows {
                    for cell in row {
                        for p in cell {
                            if let part = p.image {
                                parts.append(part)
                            }
                        }
                    }
                }
            }
        }
        let images = loadImages(parts: parts, filePath: filePath, maxPixelBudget: budget)
        let plan = CGElementDrawer.layoutDocxBlocks(in: document, maxHeight: docSize.height)

        return try renderBitmap(logicalSize: docSize, maxSize: maxSize) { ctx in
            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(origin: .zero, size: docSize))
            for idx in plan.zOrder {
                CGElementDrawer.drawDocxPlacement(in: ctx, placement: plan.placements[idx], images: images)
            }
        }
    }

    private static func renderXlsxSheet(
        document: OfficeDocument,
        filePath: String,
        sheetIndex: Int,
        maxSize: CGSize
    ) throws -> CGImage {
        guard !document.sheets.isEmpty else {
            throw OfficeError.renderFailed("Spreadsheet has no sheets")
        }
        let clampedIndex = max(0, min(document.sheets.count - 1, sheetIndex))
        let sheet = document.sheets[clampedIndex]
        let (_, _, totalW, totalH) = CGElementDrawer.computeSheetExtents(sheet)
        let previewW = max(200, min(totalW > CGElementDrawer.sheetHeaderWidth ? totalW : 400, 800))
        let previewH = max(150, min(totalH > CGElementDrawer.sheetHeaderHeight ? totalH : 300, 600))
        let previewSize = CGSize(width: previewW, height: previewH)
        let viewport = CGRect(origin: .zero, size: previewSize)

        // 按视口收集可见的浮动图片并按总预算均摊解码，保证 PNG 导出与封面/主预览一致
        let neededParts = CGElementDrawer.visibleSheetImageParts(sheet: sheet, viewport: viewport)
        let images: [String: CGImage]
        if neededParts.isEmpty {
            images = [:]
        } else {
            let perImageBudget = max(200_000, 4_000_000 / max(1, neededParts.count))
            images = loadImages(parts: neededParts, filePath: filePath, maxPixelBudget: perImageBudget)
        }

        return try renderBitmap(logicalSize: previewSize, maxSize: maxSize) { ctx in
            CGElementDrawer.drawSpreadsheet(
                in: ctx,
                sheet: sheet,
                styles: document.cellStyles,
                viewport: viewport,
                images: images
            )
        }
    }
}
