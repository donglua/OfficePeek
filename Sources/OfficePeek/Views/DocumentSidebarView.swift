import SwiftUI
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
        .frame(width: 210)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    private var sidebarHeader: some View {
        HStack {
            Text(sidebarTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            LazyVStack(spacing: 10) {
                ForEach(1...max(1, pageCount), id: \.self) { pageNumber in
                    let isSelected = controller.currentPage == pageNumber
                    Button {
                        controller.jumpToPage(pageNumber)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white)
                                if let img = pageThumbnailCache.pageImages[pageNumber] {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(5)
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                            .frame(height: 98)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                        lineWidth: isSelected ? 2.5 : 1
                                    )
                            )

                            HStack {
                                Text("第 \(pageNumber) 页")
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                Spacer()
                            }
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
                    let isSelected = controller.currentPage == sheetNumber
                    Button {
                        controller.selectSheet(sheetNumber)
                    } label: {
                        HStack(spacing: 8) {
                            Text("📊")
                                .font(.system(size: 12))
                            Text(name)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .primary)
                                .lineLimit(1)
                            Spacer()
                            Text("#\(sheetNumber)")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private func docxInspector(meta: OfficeMetadata) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("版面属性")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    infoRow(label: "格式", value: "Word (DOCX)")
                    infoRow(label: "排版模式", value: "连续滚动流")
                    infoRow(label: "页面宽度", value: String(format: "%.0f pt", meta.widthPt))
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("兼容提示 (\(meta.warnings.count))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    if meta.warnings.isEmpty {
                        Text("未发现未支持的复杂元素，文档可完整预览。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(meta.warnings.enumerated()), id: \.offset) { _, warn in
                            Text("• \(warn)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
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
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
        }
    }
}
