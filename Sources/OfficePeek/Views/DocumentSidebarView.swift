import SwiftUI
import AppKit
import Foundation
import JZOffice
import OfficePeekKit

/// 阅读器左侧导航栏：
/// - PPTX：展示每页幻灯片缩略图列表，点击跳页
/// - XLSX：展示工作表目录，点击切换工作表
/// - DOCX：展示文档画幅尺寸、文件大小、Finder 定位及兼容提示详情
struct DocumentSidebarView: View {
    let fileURL: URL
    @ObservedObject var controller: OfficePreviewController
    @ObservedObject var pageThumbnailCache: PageThumbnailCache

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            Rectangle()
                .fill(ThemeColor.hairlineSeparator)
                .frame(height: 1)

            if let meta = controller.metadata {
                switch meta.format {
                case .pptx:
                    pptxSlideThumbnailsList(pageCount: meta.pageCount)
                case .xlsx:
                    xlsxSheetsOutline(sheets: meta.sheetNames)
                case .docx:
                    docxInspector(meta: meta)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: 228)
        .background(.regularMaterial)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 6) {
            if let symbol = headerSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text(sidebarTitle)
                .font(ThemeTypography.sectionHeader)
                .foregroundColor(.secondary)

            Spacer()

            if let countText = headerCountText {
                Text(countText)
                    .font(ThemeTypography.sidebarBadge)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(ThemeColor.segmentedTrackBackground)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var headerSymbol: String? {
        guard let kind = controller.metadata?.format else { return nil }
        switch kind {
        case .pptx:
            return "play.rectangle"
        case .xlsx:
            return "tablecells"
        case .docx:
            return "info.circle"
        }
    }

    private var sidebarTitle: String {
        guard let kind = controller.metadata?.format else { return "文档导航" }
        switch kind {
        case .pptx:
            return "幻灯片导航"
        case .xlsx:
            return "工作表目录"
        case .docx:
            return "文档信息与概览"
        }
    }

    private var headerCountText: String? {
        guard let kind = controller.metadata?.format else { return nil }
        switch kind {
        case .pptx:
            return "\(controller.pageCount)"
        case .xlsx:
            return "\(controller.sheetNames.count)"
        case .docx:
            return nil
        }
    }

    private func pptxSlideThumbnailsList(pageCount: Int) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                ForEach(1...max(1, pageCount), id: \.self) { pageNumber in
                    SlideThumbnailItemView(
                        pageNumber: pageNumber,
                        image: pageThumbnailCache.pageImages[pageNumber],
                        isSelected: controller.currentPage == pageNumber,
                        onSelect: {
                            controller.jumpToPage(pageNumber)
                        }
                    )
                    .onAppear {
                        pageThumbnailCache.loadPageThumbnail(from: fileURL, pageNumber: pageNumber)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func xlsxSheetsOutline(sheets: [String]) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(sheets.enumerated()), id: \.offset) { idx, name in
                    let sheetNumber = idx + 1
                    SheetRowItemView(
                        name: name,
                        sheetNumber: sheetNumber,
                        isSelected: controller.currentPage == sheetNumber,
                        onSelect: {
                            controller.selectSheet(sheetNumber)
                        }
                    )
                }
            }
            .padding(8)
        }
    }

    private func docxInspector(meta: OfficeMetadata) -> some View {
        let formattedSize = formattedFileSizeString()
        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ThemeColor.docxPrimary)
                        Text("版面属性")
                            .font(ThemeTypography.sectionHeader)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        infoRow(label: "格式", value: "Word DOCX")
                        Rectangle().fill(ThemeColor.hairlineSeparator).frame(height: 1)
                        infoRow(label: "页面排版", value: "连续流")
                        Rectangle().fill(ThemeColor.hairlineSeparator).frame(height: 1)
                        infoRow(label: "页面宽度", value: String(format: "%.0f pt", meta.widthPt))
                        if let formattedSize {
                            Rectangle().fill(ThemeColor.hairlineSeparator).frame(height: 1)
                            infoRow(label: "文件大小", value: formattedSize)
                        }
                    }
                    .padding(11)
                    .background(
                        RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                            .fill(ThemeColor.cardBackground.opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                            .strokeBorder(ThemeColor.subtleBorder, lineWidth: 0.75)
                    )
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                } label: {
                    Label("在 Finder 中显示", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: meta.warnings.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(meta.warnings.isEmpty ? .green : .orange)
                        Text("兼容提示 (\(meta.warnings.count))")
                            .font(ThemeTypography.sectionHeader)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    if meta.warnings.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                            Text("排版元素均被原生支持")
                                .font(ThemeTypography.bodySecondary)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.green.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.green.opacity(0.18), lineWidth: 0.75)
                        )
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(meta.warnings.enumerated()), id: \.offset) { _, warn in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.orange)
                                        .padding(.top, 1)
                                    Text(warn)
                                        .font(ThemeTypography.bodySecondary)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.orange.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.75)
                                )
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func formattedFileSizeString() -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = (attrs[.size] as? NSNumber)?.int64Value else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ThemeTypography.bodySecondary)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(ThemeTypography.monospacedValue)
                .foregroundColor(.primary)
        }
    }
}

private struct SlideThumbnailItemView: View {
    let pageNumber: Int
    let image: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void

    private typealias ViewState = SwiftUI.State
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white)

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        skeletonSlidePlaceholder
                    }
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : (isHovered ? ThemeColor.elevatedBorder : ThemeColor.subtleBorder),
                            lineWidth: isSelected ? 2 : 0.75
                        )
                )
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.18 : (isHovered ? 0.12 : 0.06)),
                    radius: isSelected ? 6 : 3,
                    x: 0,
                    y: isSelected ? 2 : 1
                )

                HStack {
                    Text("幻灯片 \(String(format: "%02d", pageNumber))")
                        .font(ThemeTypography.monospacedValue)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                    Spacer()
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var skeletonSlidePlaceholder: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ThemeColor.skeletonFill)
                .frame(width: 44, height: 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(ThemeColor.skeletonFill)
                .frame(maxWidth: .infinity)
                .frame(height: 10)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(ThemeColor.skeletonFill)
                .frame(width: 110, height: 7)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(ThemeColor.skeletonFill)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
        .padding(12)
    }
}

private struct SheetRowItemView: View {
    let name: String
    let sheetNumber: Int
    let isSelected: Bool
    let onSelect: () -> Void

    private typealias ViewState = SwiftUI.State
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : ThemeColor.xlsxPrimary)

                Text(name)
                    .font(ThemeTypography.bodyPrimary.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer()

                Text("#\(sheetNumber)")
                    .font(ThemeTypography.monospacedValue)
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor : (isHovered ? ThemeColor.hoverBackground : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
