import SwiftUI
import JZOffice

/// DOCX / PPTX / XLSX / CSV / TSV 彩色格式徽章
public struct FormatBadgeView: View {
    public let kind: OfficeKind
    public let label: String?
    public var compact: Bool

    public init(kind: OfficeKind, label: String? = nil, compact: Bool = false) {
        self.kind = kind
        self.label = label
        self.compact = compact
    }

    /// 结合底层文档类型与文件扩展名解析徽章展示文案（CSV / TSV 复用 XLSX 表格引擎，界面上直观区分）
    public static func badgeLabel(for kind: OfficeKind, fileURL: URL) -> String {
        if kind == .xlsx {
            switch fileURL.pathExtension.lowercased() {
            case "csv":
                return "CSV"
            case "tsv":
                return "TSV"
            default:
                break
            }
        }
        return kind.rawValue
    }

    private var cornerRadius: CGFloat {
        compact ? 5 : 6
    }

    private var horizontalPadding: CGFloat {
        compact ? 6 : 8
    }

    private var verticalPadding: CGFloat {
        compact ? 2.5 : 3.5
    }

    public var body: some View {
        Text(label ?? kind.rawValue)
            .font(ThemeTypography.captionBadge)
            .tracking(0.3)
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ThemeColor.color(for: kind))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
            )
    }
}
