import SwiftUI

struct MeshGradientEditor: View {
    @Binding var gradient: MeshGradientDefinition
    @State private var selectedPoints = Set<MeshGradientPoint.ID>()
    
    @AppStorage("controlsVisible")
    private var controlsVisible = true

    var body: some View {
        MeshGradientCanvas(gradient: $gradient, selectedPoints: $selectedPoints, controlsVisible: $controlsVisible)
            .inspector(isPresented: .constant(true)) {
                MeshGradientInspector(gradient: $gradient, selectedPoints: $selectedPoints)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    primaryToolbar
                }
            }
    }

    @ViewBuilder
    private var primaryToolbar: some View {
        let visibilityHelp: LocalizedStringKey = controlsVisible ? "Hide Controls" : "Show Controls"
        Toggle(
            visibilityHelp,
            systemImage: "square.on.square.squareshape.controlhandles",
            isOn: $controlsVisible
        )
        .help(visibilityHelp)

        Button {
            withAnimation(.smooth) {
                gradient.distortPoints(frequency: 4, amplitude: 0.3)
            }
        } label: {
            Image(systemName: "wand.and.sparkles.inverse")
        }
        .help("Apply perlin noise")

        Button {
            withAnimation(.smooth) {
                gradient.randomize()
            }
        } label: {
            Image(systemName: "dice")
        }
        .help("Randomize points")

        Button {
            withAnimation(.smooth) {
                gradient.resetPointPositions()
            }
        } label: {
            Image(systemName: "eraser")
        }
        .help("Reset points")
    }
}

// MARK: - Canvas

extension MeshGradientDefinition {
    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: viewPortWidth, height: viewPortHeight)
    }
}

struct MeshGradientCanvas: View {

    @Binding var gradient: MeshGradientDefinition
    @Binding var selectedPoints: Set<MeshGradientPoint.ID>
    @Binding var controlsVisible: Bool

    @Environment(\.colorScheme)
    private var colorScheme

    private func scale(in proxy: GeometryProxy) -> CGFloat {
        let w = proxy.size.width / CGFloat(gradient.viewPortWidth)
        let h = proxy.size.height / CGFloat(gradient.viewPortHeight)
        return min(w, h)
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = scale(in: proxy)
            let x = proxy.size.width * 0.5
            let y = proxy.size.height * 0.5
            content
                .position(x: x, y: y)
                .scaleEffect(scale)
        }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color.black : Color.white)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ZStack {
                if gradient.width > 0 && gradient.height > 0 {
                    MeshGradient(
                        width: gradient.width,
                        height: gradient.height,
                        points: gradient.simdPoints,
                        colors: gradient.colors,
                        background: gradient.backgroundColor,
                        smoothsColors: gradient.smoothsColors,
                        colorSpace: gradient.colorSpace
                    )
                }

                ForEach(gradient.points) { point in
                    MeshGradientPointHandle(
                        point: point,
                        viewPort: gradient.bounds,
                        gradient: gradient,
                        isSelected: selectedPoints.contains(point.id),
                        isVisible: controlsVisible
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(with: gradient.bounds))
            .animation(.snappy, value: controlsVisible)
        }
        .frame(width: CGFloat(gradient.viewPortWidth), height: CGFloat(gradient.viewPortHeight))
    }

    @State private var dragReferenceTranslation = CGSize.zero
    @State private var dragGestureCanModifySelection = true

    private func dragGesture(with viewPort: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard controlsVisible else { return }

                if dragGestureCanModifySelection {
                    if let targetPoint = gradient.point(at: value.location, in: viewPort) {
                        let commandPressed = NSEvent.modifierFlags.contains(.command)
                        let optionPressed = NSEvent.modifierFlags.contains(.command)

                        if commandPressed {
                            selectedPoints.insert(targetPoint.id)
                        } else if optionPressed {
                            selectedPoints.remove(targetPoint.id)
                        } else {
                            if !selectedPoints.contains(targetPoint.id) {
                                selectedPoints = [targetPoint.id]
                            }
                        }
                        print(targetPoint)
                    } else {
                        selectedPoints.removeAll()
                        /// Adding points not currently supported because adding arbitrary points doesn't work,
                        /// it would have to be a feature where an entire column/row can be added at a certain point.
                        return
//                        print("New \(Int(Date.now.timeIntervalSinceReferenceDate))")
//
//                        let relativePosition = CGPoint(
//                            x: value.location.x / viewPort.size.width,
//                            y: value.location.y / viewPort.size.height
//                        )
//
//                        let newPoint = gradient.addPoint(at: relativePosition, color: .indigo)
//                        selectedPoints.insert(newPoint.id)
                    }

                    dragGestureCanModifySelection = false
                }

                let relativeTranslation = CGSize(
                    width: (value.translation.width - dragReferenceTranslation.width) / viewPort.width,
                    height: (value.translation.height - dragReferenceTranslation.height) / viewPort.height
                )

                dragReferenceTranslation = value.translation

                for pointID in selectedPoints {
                    gradient.nudgePoint(id: pointID, by: relativeTranslation)
                }
            }
            .onEnded { _ in
                guard controlsVisible else { return }

                dragReferenceTranslation = .zero
                dragGestureCanModifySelection = true
            }
    }
}

struct MeshGradientPointHandle: View {
    nonisolated static var size: CGFloat { 12 }

    var point: MeshGradientPoint
    var viewPort: CGRect
    var gradient: MeshGradientDefinition
    var isSelected: Bool
    var isVisible: Bool

    var body: some View {
        let pos = point.position(in: viewPort)

        Circle()
            .fill(point.color)
            .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
            .shadow(radius: 2)
            .frame(width: Self.size, height: Self.size)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.4)
            .position(pos)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var definition = MeshGradientDefinition.init(
        viewPortWidth: 512,
        viewPortHeight: 512,
        width: 5,
        height: 5,
        colorPalette: nil,
        colorDistribution: .random,
        smoothsColors: true,
        backgroundColor: .randomSystemColor(),
        colorSpace: .device
    )

    MeshGradientEditor(gradient: $definition)
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
}
#endif
