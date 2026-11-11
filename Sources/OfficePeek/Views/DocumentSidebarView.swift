import SwiftUI
import Foundation
import JZOffice
import OfficePeekKit

/// 阅读器左侧导航栏：
/// - PPTX：展示每页幻灯片缩略图列表，点击跳页
/// - XLSX：展示工作表目录，点击切换工作表
/// - DOCX：展示文档画幅尺寸、页数及兼容提示详情
struct DocumentSidebarView: View {
    let fileURL: URL
    @ObservedObject var controller: OfficePreviewController
    @ObservedObject var pageThumbnailCache: PageThumbnailCache

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            Divider()

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
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: 220)
        .background(.regularMaterial)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 6) {
            if let symbol = headerSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text(sidebarTitle)
                .font(ThemeTypography.sectionHeader)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            return "幻灯片导航 (\(controller.pageCount))"
        case .xlsx:
            return "工作表目录 (\(controller.sheetNames.count))"
        case .docx:
            return "文档信息与概览"
        }
    }

    private func pptxSlideThumbnailsList(pageCount: Int) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                ForEach(1...max(1, pageCount), id: \.self) { pageNumber in
                    let isSelected = controller.currentPage == pageNumber
                    Button {
                        controller.jumpToPage(pageNumber)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white)
                                if let img = pageThumbnailCache.pageImages[pageNumber] {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                            .frame(height: 98)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: Color.black.opacity(isSelected ? 0.20 : 0.08),
                                radius: isSelected ? 5 : 2,
                                y: 1
                            )

                            HStack {
                                Text("幻灯片 \(String(format: "%02d", pageNumber))")
                                    .font(ThemeTypography.captionBadge)
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 2)
                        }
                        .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        pageThumbnailCache.loadPageThumbnail(from: fileURL, pageNumber: pageNumber)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func xlsxSheetsOutline(sheets: [String]) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
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
                        Divider().opacity(0.5)
                        infoRow(label: "页面排版", value: "连续流")
                        Divider().opacity(0.5)
                        infoRow(label: "页面宽度", value: String(format: "%.0f pt", meta.widthPt))
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ThemeColor.subtleBorder, lineWidth: 1)
                    )
                }

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
                                .fill(Color.green.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.green.opacity(0.15), lineWidth: 1)
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
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.orange.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
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
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
