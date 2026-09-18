#if canImport(SwiftUI)
import AppKit
import SwiftUI
import SYDownloadCore

// SYDownload-specific presentation helpers.
// Reusable design tokens and interaction patterns live in CoreUI.

extension DownloadPlatform {
    var designColor: Color {
        switch self {
        case .xiaohongshu, .douyin:
            return CoreColor.accent
        case .unknown:
            return CoreColor.textSecondary
        }
    }

    var brandAssetName: String? {
        switch self {
        case .xiaohongshu:
            return "XiaohongshuPlatformIcon"
        case .douyin:
            return "DouyinPlatformIcon"
        case .unknown:
            return nil
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .xiaohongshu:
            return "book.pages.fill"
        case .douyin:
            return "music.note"
        case .unknown:
            return "link"
        }
    }
}

struct AppMark: View {
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("SYDownload")
    }
}

struct IconBadge: View {
    let systemImage: String
    var tint: Color = CoreColor.accent
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CoreRadius.row, style: .continuous)
                .fill(tint.opacity(0.10))

            Image(systemName: systemImage)
                .font(.system(size: CoreMetrics.controlIconSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PlatformBrandIcon: View {
    let platform: DownloadPlatform
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = brandImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(platform.designColor.opacity(0.09))

                    Image(systemName: platform.fallbackSymbol)
                        .font(CoreTypography.controlFont)
                        .foregroundStyle(platform.designColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var brandImage: NSImage? {
        guard let assetName = platform.brandAssetName,
              let url = Bundle.module.url(forResource: assetName, withExtension: "jpg")
        else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

struct PlatformThumbnail: View {
    let platform: DownloadPlatform
    var size: CGFloat = 56

    var body: some View {
        PlatformBrandIcon(
            platform: platform,
            size: size,
            cornerRadius: CoreRadius.row
        )
        .accessibilityLabel(platform.displayName)
    }
}

/// Business mapping from download state to the shared CoreUI visual language.
struct StatusPill: View {
    let state: DownloadTaskState

    var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: symbol)
                .font(CoreTypography.groupLabelFont)

            Text(state.label)
                .coreTypography(CoreTypography.groupLabel)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch state {
        case .queued:
            return "clock"
        case .downloading:
            return "arrow.down.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .queued, .cancelled:
            return CoreColor.textSecondary
        case .downloading:
            return CoreColor.accent
        case .completed:
            return CoreColor.success
        case .failed:
            return CoreColor.danger
        }
    }
}
#endif
