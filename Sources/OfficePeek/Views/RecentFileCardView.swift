import SwiftUI
import AppKit
import JZOffice
import OfficePeekKit

/// 最近打开文档卡片组件，支持鼠标悬浮动效、毛玻璃固定图钉与右键快捷菜单
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
                Divider()
                fileInfoArea
            }
            .background(
                RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeRadius.medium, style: .continuous)
                    .stroke(
                        isHovered ? Color.accentColor.opacity(0.4) : ThemeColor.subtleBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.14 : 0.04),
                radius: isHovered ? 8 : 2,
                x: 0,
                y: isHovered ? 4 : 1
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
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
        ZStack(alignment: .topTrailing) {
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.5)

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .padding(8)
                } else {
                    placeholderPaperView
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(spacing: 6) {
                if item.isPinned || isHovered {
                    pinButton
                }
                FormatBadgeView(kind: item.format, compact: true)
            }
            .padding(8)
        }
    }

    private var placeholderPaperView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ThemeColor.tint(for: item.format))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(ThemeColor.color(for: item.format).opacity(0.20), lineWidth: 0.5)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)

            Image(systemName: formatSymbolName)
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(ThemeColor.color(for: item.format).opacity(0.20))

            ProgressView()
                .scaleEffect(0.7)
        }
    }

    private var pinButton: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)

            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(item.isPinned ? .orange : .secondary)
        }
        .contentShape(Circle())
        .onTapGesture {
            onTogglePin()
        }
        .help(item.isPinned ? "取消固定" : "固定到顶部")
    }

    private var fileInfoArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayName)
                .font(ThemeTypography.bodyPrimary.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text(item.pageSummary)
                Text("·")
                Text(item.formattedFileSize)
            }
            .font(ThemeTypography.bodySecondary)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }
}
