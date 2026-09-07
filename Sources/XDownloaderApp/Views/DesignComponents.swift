#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu: return .red
        case .douyin, .tiktok: return .primary
        case .unknown: return .secondary
        }
    }

    var designSymbol: String {
        switch self {
        case .xiaohongshu: return "book.pages.fill"
        case .douyin, .tiktok: return "music.note"
        case .unknown: return "link"
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.accentColor)
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: 1)
        }
        .frame(width: size, height: size)
    }
}

struct PlatformChip: View {
    let platform: DownloadPlatform
    var selected = false

    var body: some View {
        Label(platform.displayName, systemImage: platform.designSymbol)
            .font(.system(size: 12, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PlatformThumbnail: View {
    let platform: DownloadPlatform
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .fill(Color.primary.opacity(0.045))
            Image(systemName: platform.designSymbol)
                .font(.system(size: size * 0.30, weight: .semibold))
                .foregroundStyle(platform.designColor)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let state: DownloadTaskState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
            Text(state.label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.09), in: Capsule())
    }

    private var symbol: String {
        switch state {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .queued: return .secondary
        case .downloading: return .accentColor
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct DesignCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

extension View {
    func designCard() -> some View { modifier(DesignCardModifier()) }
}
#endif
