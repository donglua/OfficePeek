import SwiftUI
import JZOffice

/// DOCX / PPTX / XLSX 彩色格式徽章
public struct FormatBadgeView: View {
    public let kind: OfficeKind
    public var compact: Bool

    public init(kind: OfficeKind, compact: Bool = false) {
        self.kind = kind
        self.compact = compact
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
        Text(kind.rawValue)
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
