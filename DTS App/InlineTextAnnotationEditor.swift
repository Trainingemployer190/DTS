import SwiftUI
import UIKit

struct TextOverlay: Identifiable, Equatable {
    let id: UUID
    var text: String
    var position: CGPoint // normalized 0..1
    var fontSize: CGFloat
    var isEditing: Bool

    init(id: UUID = UUID(), text: String = "Tap to edit", position: CGPoint, fontSize: CGFloat = 18, isEditing: Bool = true) {
        self.id = id
        self.text = text
        self.position = position
        self.fontSize = fontSize
        self.isEditing = isEditing
    }
}

struct InlineTextAnnotationEditor: View {
    let image: UIImage
    var existingTextOverlays: [TextOverlay] = []
    var onCancel: () -> Void
    var onSave: (UIImage) -> Void

    @State private var overlays: [TextOverlay] = []
    @State private var selectedId: UUID? = nil
    @State private var currentFontSize: CGFloat = 18
    @FocusState private var focusedOverlayId: UUID?
    @State private var didTapOverlay: Bool = false

    init(image: UIImage, existingTextOverlays: [TextOverlay] = [], onCancel: @escaping () -> Void, onSave: @escaping (UIImage) -> Void) {
        self.image = image
        self.existingTextOverlays = existingTextOverlays
        self.onCancel = onCancel
        self.onSave = onSave
        _overlays = State(initialValue: existingTextOverlays)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    PhotoAnnotationCanvas(image: image) { displayedSize, converters in
                        // Invisible layer to catch taps on empty canvas only
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        let point = value.location
                                        print("[Canvas] tap at: \(point.x.rounded()), \(point.y.rounded())")
                                        // If tap was on/near an overlay, select it instead of adding
                                        if let hit = hitTestOverlay(at: point, converters: converters) {
                                            print("[HitTest] hit overlay: \(hit.id) dist within radius")
                                            didTapOverlay = true
                                            selectForEditing(hit)
                                        } else if !didTapOverlay {
                                            let normalized = converters.toNormalized(point)
                                            print("[Overlay] add at normalized: \(normalized.x.rounded(toPlaces: 3)), \(normalized.y.rounded(toPlaces: 3))")
                                            addOverlay(at: normalized)
                                        }
                                        didTapOverlay = false
                                    }
                            )

                        // Render overlays
                        ForEach(overlays) { overlay in
                            overlayView(overlay: overlay, converters: converters)
                        }
                    }
                }
            }
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let rendered = renderImage()
                        onSave(rendered)
                    }
                    .disabled(overlays.isEmpty)
                }
            }
        }
    }

    // MARK: - Overlay View

    @ViewBuilder
    private func overlayView(overlay: TextOverlay, converters: CanvasConverters) -> some View {
        let viewPoint = converters.toView(overlay.position)
        // A container that handles tap selection and drag when editing
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                // Background bubble
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))

                // Text content
                if overlay.isEditing {
                    TextField("Tap to edit", text: binding(for: overlay).text)
                        .font(.system(size: overlay.fontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .focused($focusedOverlayId, equals: overlay.id)
                        .onAppear {
                            // Ensure keyboard focuses on creation/selection
                            print("[Overlay] focus id=\(overlay.id)")
                            focusedOverlayId = overlay.id
                            selectedId = overlay.id
                            currentFontSize = overlay.fontSize
                        }
                } else {
                    Text(overlay.text)
                        .font(.system(size: overlay.fontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }

                // Delete (top-left)
                HStack {
                    Button {
                        deleteOverlay(overlay)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Circle().fill(Color.white))
                    }
                    .padding(6)

                    Spacer()

                    // Done (top-right)
                    Button {
                        finishEditing(overlay)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .background(Circle().fill(Color.white))
                    }
                    .padding(6)
                }
            }
            .frame(minWidth: 80)

            // Font size slider while editing
            if overlay.isEditing {
                HStack {
                    Image(systemName: "textformat.size.smaller").foregroundColor(.white)
                    Slider(value: binding(for: overlay).fontSize, in: 12...72, step: 1) {
                        Text("Font Size")
                    } minimumValueLabel: { EmptyView() } maximumValueLabel: { EmptyView() }
                    Image(systemName: "textformat.size.larger").foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .fixedSize()
        .position(viewPoint)
        .gesture(
            DragGesture()
                .onChanged { value in
                    didTapOverlay = true
                    if selectedId == overlay.id && overlay.isEditing {
                        let newNorm = converters.toNormalized(value.location)
                        updatePosition(overlay, to: newNorm)
                    }
                }
        )
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    didTapOverlay = true
                    selectForEditing(overlay)
                }
        )
    }

    // MARK: - Actions

    private func addOverlay(at normalized: CGPoint) {
        print("[Overlay] creating new overlay id=\(UUID().uuidString) at=\(String(format: "%.3f", normalized.x)),\(String(format: "%.3f", normalized.y))")
        let new = TextOverlay(position: normalized)
        overlays.append(new)
        selectedId = new.id
        currentFontSize = new.fontSize
        didTapOverlay = true
        // Focus the just-created overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedOverlayId = new.id
        }
    }

    private func selectForEditing(_ overlay: TextOverlay) {
        print("[Overlay] select id=\(overlay.id)")
        guard let index = overlays.firstIndex(where: { $0.id == overlay.id }) else { return }
        overlays[index].isEditing = true
        selectedId = overlay.id
        currentFontSize = overlays[index].fontSize
        focusedOverlayId = overlay.id
    }

    private func finishEditing(_ overlay: TextOverlay) {
        print("[Overlay] done id=\(overlay.id)")
        guard let index = overlays.firstIndex(where: { $0.id == overlay.id }) else { return }
        overlays[index].isEditing = false
        if overlays[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            overlays[index].text = ""
        }
        if selectedId == overlay.id { selectedId = nil }
        focusedOverlayId = nil
    }

    private func deleteOverlay(_ overlay: TextOverlay) {
        print("[Overlay] delete id=\(overlay.id)")
        overlays.removeAll { $0.id == overlay.id }
        if selectedId == overlay.id { selectedId = nil }
        if focusedOverlayId == overlay.id { focusedOverlayId = nil }
    }

    private func updatePosition(_ overlay: TextOverlay, to normalized: CGPoint) {
        print("[Overlay] drag id=\(overlay.id) -> \(String(format: "%.3f", normalized.x)),\(String(format: "%.3f", normalized.y))")
        guard let index = overlays.firstIndex(where: { $0.id == overlay.id }) else { return }
        overlays[index].position = CGPoint(x: max(0, min(1, normalized.x)), y: max(0, min(1, normalized.y)))
    }

    private func binding(for overlay: TextOverlay) -> (text: Binding<String>, fontSize: Binding<CGFloat>) {
        guard let index = overlays.firstIndex(where: { $0.id == overlay.id }) else {
            return (Binding.constant(overlay.text), Binding.constant(overlay.fontSize))
        }
        return (
            Binding(get: { overlays[index].text }, set: { overlays[index].text = $0 }),
            Binding(get: { overlays[index].fontSize }, set: { overlays[index].fontSize = $0 })
        )
    }

    // MARK: - Rendering

    private func renderImage() -> UIImage {
        let baseSize = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: baseSize, format: format)

        return renderer.image { ctx in
            // Draw base image
            image.draw(in: CGRect(origin: .zero, size: baseSize))

            for overlay in overlays {
                let font = UIFont.systemFont(ofSize: overlay.fontSize, weight: .semibold)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white,
                    .strokeColor: UIColor.black,
                    .strokeWidth: -2.0
                ]
                let string = NSAttributedString(string: overlay.text, attributes: attributes)
                let textSize = string.size()

                // Convert normalized position to pixel position
                let point = CGPoint(x: overlay.position.x * baseSize.width, y: overlay.position.y * baseSize.height)
                let drawRect = CGRect(x: point.x - textSize.width/2, y: point.y - textSize.height/2, width: textSize.width, height: textSize.height)
                string.draw(in: drawRect)
            }
        }
    }

    private func hitTestOverlay(at viewPoint: CGPoint, converters: CanvasConverters) -> TextOverlay? {
        // Simple proximity hit test based on distance to overlay center and font size
        // Treat hit radius as max(44pt, fontSize * 0.8)
        for overlay in overlays.reversed() { // top-most last wins
            let center = converters.toView(overlay.position)
            let dx = viewPoint.x - center.x
            let dy = viewPoint.y - center.y
            let dist = sqrt(dx*dx + dy*dy)
            let radius = max(44, overlay.fontSize * 0.8)
            if dist <= radius {
                print("[HitTest] checking id=\(overlay.id) dist=\(String(format: "%.1f", dist)) radius=\(String(format: "%.1f", radius)) -> HIT")
                return overlay
            }
        }
        return nil
    }
}

#Preview {
    InlineTextAnnotationEditor(
        image: UIImage(systemName: "photo")!.withTintColor(.lightGray, renderingMode: .alwaysOriginal),
        onCancel: {},
        onSave: { _ in }
    )
}


private extension CGFloat {
    func rounded(toPlaces places: Int) -> String {
        let fmt = "%.\(places)f"
        return String(format: fmt, Double(self))
    }
}
