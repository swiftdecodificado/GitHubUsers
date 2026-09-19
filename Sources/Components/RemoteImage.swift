import GitHubAPI
import ImageIO
import SwiftUI

struct RemoteImage: View {
    let url: URL
    let name: String

    @Environment(\.imageCache) private var images
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    @State private var decoded: CGImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.quaternary)

                Text(String(name.prefix(1)).uppercased())
                    .font(.largeTitle.bold())
                    .foregroundStyle(.secondary)

                if let decoded {
                    Image(decorative: decoded, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .task(id: url) {
                decoded = nil

                do {
                    guard let images else {
                        return
                    }

                    let data = try await images.data(for: url)
                    try Task.checkCancellation()

                    guard let image = await Self.decodeThumbnail(
                        data,
                        targetSize: geometry.size,
                        displayScale: displayScale,
                    ) else {
                        return
                    }

                    withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) {
                        decoded = image
                    }
                } catch { /* Initial fallback remains visible, including during cancellation. */ }
            }
        }
        .accessibilityLabel(L10n.avatar(name))
    }

    private static func decodeThumbnail(
        _ data: Data,
        targetSize: CGSize,
        displayScale: CGFloat,
    ) async -> CGImage? {
        let task = Task<CGImage?, Never>.detached(priority: .utility) {
            guard !Task.isCancelled,
                  let source = CGImageSourceCreateWithData(data as CFData, nil)
            else {
                return nil
            }

            let maximumPixelSize = max(
                1,
                Int(ceil(max(targetSize.width, targetSize.height) * displayScale)),
            )
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
            ]

            guard !Task.isCancelled else {
                return nil
            }

            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }

        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

extension EnvironmentValues {
    @Entry var imageCache: GitHubImageCache?
}
