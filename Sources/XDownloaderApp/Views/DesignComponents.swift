#if canImport(SwiftUI)
import SwiftUI
import XDownloaderCore

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu: return .red
        case .douyin, .tiktok: return Color(red: 0.05, green: 0.06, blue: 0.08)
        case .unknown: return .secondary
        }
    }

    var designSymbol: String {
        switch self {
        case .xiaohongshu: return "book.pages.fill"
        case .douyin: return "music.note"
        case .tiktok: return "play.fill"
        case .unknown: return "link"
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.10, blue: 0.20), Color(red: 0.08, green: 0.10, blue: 0.24), Color(red: 0.31, green: 0.02, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.18), radius: size * 0.12, y: size * 0.06)
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.48, weight: .black, design: .rounded))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .cyan)
        }
        .frame(width: size, height: size)
    }
}

struct PlatformChip: View {
    let platform: DownloadPlatform
    var selected = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(platform.designColor)
                Image(systemName: platform.designSymbol).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 20, height: 20)
            Text(platform.displayName).font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor)))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1) }
    }
}

struct PlatformThumbnail: View {
    let platform: DownloadPlatform
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(gradient)
            Image(systemName: symbol).font(.system(size: size * 0.32, weight: .semibold)).foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: size, height: size)
    }

    private var gradient: LinearGradient {
        switch platform {
        case .xiaohongshu:
            return LinearGradient(colors: [Color(red: 0.22, green: 0.58, blue: 0.92), Color(red: 0.50, green: 0.78, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .douyin:
            return LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.18), Color(red: 0.09, green: 0.62, blue: 0.69)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .tiktok:
            return LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.66, green: 0.07, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unknown:
            return LinearGradient(colors: [.gray, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var symbol: String {
        switch platform {
        case .xiaohongshu: return "mountain.2.fill"
        case .douyin: return "music.note"
        case .tiktok: return "play.rectangle.fill"
        case .unknown: return "link"
        }
    }
}

struct StatusPill: View {
    let state: DownloadTaskState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2.weight(.bold))
            Text(state.label).font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
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
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct DesignCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1) }
    }
}

extension View {
    func designCard() -> some View { modifier(DesignCardModifier()) }
}
#endif
