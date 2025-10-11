import SwiftUI
import UIKit

// Converters between normalized image coordinates (0..1) and view coordinates
public struct CanvasConverters {
    public let toView: (CGPoint) -> CGPoint
    public let toNormalized: (CGPoint) -> CGPoint
}

// Environment key in case children need access without threading it manually
private struct CanvasConvertersKey: EnvironmentKey {
    static let defaultValue: CanvasConverters = CanvasConverters(
        toView: { _ in .zero },
        toNormalized: { _ in .zero }
    )
}

public extension EnvironmentValues {
    var canvasConverters: CanvasConverters {
        get { self[CanvasConvertersKey.self] }
        set { self[CanvasConvertersKey.self] = newValue }
    }
}

// A canvas that lays out an image with aspectFit and provides coordinate converters
public struct PhotoAnnotationCanvas<OverlayContent: View>: View {
    public let image: UIImage
    public let content: (_ displayedImageSize: CGSize, _ converters: CanvasConverters) -> OverlayContent

    public init(
        image: UIImage,
        @ViewBuilder content: @escaping (_ displayedImageSize: CGSize, _ converters: CanvasConverters) -> OverlayContent
    ) {
        self.image = image
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let imageSize = image.size
            let fitted = aspectFitRect(for: imageSize, in: containerSize)

            ZStack(alignment: .topLeading) {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fitted.size.width, height: fitted.size.height)
                    .position(x: fitted.midX, y: fitted.midY)

                // Overlay within the same fitted rect
                let converters = makeConverters(fittedRect: fitted, imageSize: imageSize)

                ZStack {
                    content(fitted.size, converters)
                }
                .frame(width: fitted.size.width, height: fitted.size.height)
                .position(x: fitted.midX, y: fitted.midY)
                .environment(\.canvasConverters, converters)
            }
            .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        }
    }

    private func aspectFitRect(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0 && imageSize.height > 0 && container.width > 0 && container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    private func makeConverters(fittedRect: CGRect, imageSize: CGSize) -> CanvasConverters {
        let toView: (CGPoint) -> CGPoint = { normalized in
            // normalized (0..1) in image space -> view coordinates inside fitted rect
            let x = fittedRect.origin.x + normalized.x * fittedRect.size.width
            let y = fittedRect.origin.y + normalized.y * fittedRect.size.height
            return CGPoint(x: x, y: y)
        }
        let toNormalized: (CGPoint) -> CGPoint = { viewPoint in
            guard fittedRect.width > 0 && fittedRect.height > 0 else { return .zero }
            let nx = (viewPoint.x - fittedRect.origin.x) / fittedRect.size.width
            let ny = (viewPoint.y - fittedRect.origin.y) / fittedRect.size.height
            return CGPoint(x: max(0, min(1, nx)), y: max(0, min(1, ny)))
        }
        return CanvasConverters(toView: toView, toNormalized: toNormalized)
    }
}

#Preview {
    VStack {
        PhotoAnnotationCanvas(image: UIImage(systemName: "photo")!.withTintColor(.lightGray, renderingMode: .alwaysOriginal)) { size, converters in
            let center = CGPoint(x: 0.5, y: 0.5)
            let pt = converters.toView(center)
            Circle()
                .fill(Color.red.opacity(0.6))
                .frame(width: 20, height: 20)
                .position(x: pt.x, y: pt.y)
        }
    }
    .padding()
}
