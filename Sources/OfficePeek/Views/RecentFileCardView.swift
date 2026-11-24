import SwiftUI
import AppKit
import JZOffice
import OfficePeekKit

/// 最近打开文档卡片组件，支持实体纸张悬浮动效、毛玻璃快捷操作与右键菜单
public struct RecentFileCardView: View {
    public let item: RecentFileRecord
    public let thumbnail: NSImage?
    public let onOpen: () -> Void
    public let onTogglePin: () -> Void
    public let onExportPDF: () -> Void
    public let onReveal: () -> Void
    public let onRemove: () -> Void

    // Disambiguate property wrapper SwiftUI.State from Xcode-only SwiftUIMacros.StateMacro
    private typealias ViewState = SwiftUI.State
    @ViewState private var isHovered = false

    public init(
        item: RecentFileRecord,
        thumbnail: NSImage?,
        onOpen: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onExportPDF: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.thumbnail = thumbnail
        self.onOpen = onOpen
        self.onTogglePin = onTogglePin
        self.onExportPDF = onExportPDF
        self.onReveal = onReveal
        self.onRemove = onRemove
    }

    private var formatSymbolName: String {
        switch item.format {
        case .docx:
            return "doc.text.fill"
        case .pptx:
            return "play.rectangle.fill"
        case .xlsx:
            return "tablecells.fill"
        }
    }

    public var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnailArea
                Rectangle()
                    .fill(ThemeColor.hairlineSeparator)
                    .frame(height: 1)
                fileInfoArea
            }
            .background(
                RoundedRectangle(cornerRadius: ThemeRadius.card, style: .continuous)
                    .fill(ThemeColor.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeRadius.card, style: .continuous)
                    .strokeBorder(
                        isHovered ? ThemeColor.elevatedBorder : ThemeColor.subtleBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.12 : 0.045),
                radius: isHovered ? 12 : 3,
                x: 0,
                y: isHovered ? 6 : 1.5
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: onOpen) {
                Label("打开文档", systemImage: "arrow.up.forward.app")
            }
            Button(action: onTogglePin) {
                Label(item.isPinned ? "取消固定" : "固定到顶部", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button(action: onReveal) {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.fileURL.path, forType: .string)
            } label: {
                Label("拷贝文件路径", systemImage: "doc.on.doc")
            }
            Button(action: onExportPDF) {
                Label("导出为矢量 PDF…", systemImage: "arrow.down.doc")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("从最近列表中移除", systemImage: "trash")
            }
        }
    }

    private var thumbnailArea: some View {
        ZStack(alignment: .top) {
            ZStack {
                ThemeColor.thumbnailStageBackground

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(
                            color: Color.black.opacity(isHovered ? 0.18 : 0.09),
                            radius: isHovered ? 8 : 3,
                            x: 0,
                            y: isHovered ? 4 : 1.5
                        )
                        .offset(y: isHovered ? -2.5 : 0)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else {
                    placeholderPaperView
                        .offset(y: isHovered ? -2.5 : 0)
                }
            }
            .frame(height: 148)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    quickActionChip(
                        systemImage: item.isPinned ? "pin.fill" : "pin",
                        foregroundColor: item.isPinned ? .orange : .secondary,
                        helpText: item.isPinned ? "取消固定" : "固定到顶部",
                        action: onTogglePin
                    )

                    quickActionChip(
                        systemImage: "folder",
                        foregroundColor: .secondary,
                        helpText: "在 Finder 中显示",
                        action: onReveal
                    )
                }
                .opacity(isHovered ? 1 : 0)
                .offset(y: isHovered ? 0 : -3)

                Spacer()

                HStack(spacing: 6) {
                    if item.isPinned {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.orange.opacity(0.30), lineWidth: 0.5)
                                )
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .help("已固定到顶部")
                    }
                    FormatBadgeView(
                        kind: item.format,
                        label: FormatBadgeView.badgeLabel(for: item.format, fileURL: item.fileURL),
                        compact: true
                    )
                }
            }
            .padding(10)
        }
    }

    private var placeholderPaperView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ThemeRadius.small, style: .continuous)
                .fill(ThemeColor.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeRadius.small, style: .continuous)
                        .fill(ThemeColor.tint(for: item.format).opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeRadius.small, style: .continuous)
                        .strokeBorder(ThemeColor.color(for: item.format).opacity(0.22), lineWidth: 0.75)
                )
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.14 : 0.06),
                    radius: isHovered ? 7 : 3,
                    x: 0,
                    y: isHovered ? 3.5 : 1.5
                )
                .padding(.horizontal, 34)
                .padding(.vertical, 16)

            Image(systemName: formatSymbolName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(ThemeColor.color(for: item.format).opacity(0.32))
        }
    }

    private func quickActionChip(
        systemImage: String,
        foregroundColor: Color,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .strokeBorder(ThemeColor.subtleBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)

            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(foregroundColor)
        }
        .contentShape(Circle())
        .onTapGesture(perform: action)
        .help(helpText)
    }

    private var fileInfoArea: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            Text(item.displayName)
                .font(ThemeTypography.cardTitle)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text("\(item.pageSummary) · \(item.formattedFileSize)")
                    .monospacedDigit()
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(item.relativeLastOpenedText())
                    .lineLimit(1)
                    .foregroundColor(.secondary.opacity(0.85))
            }
            .font(ThemeTypography.metaCaption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, 10)
    }
}
