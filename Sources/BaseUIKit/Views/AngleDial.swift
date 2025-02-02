import SwiftUI

public struct AngleDial: View {
    private let angle: Binding<Angle>
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void
    @State private var isDragging = false

    public init(
        angle: Binding<Angle>,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.angle = angle
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }
    
    public var body: some View {
        DialTrackShape()
            .fill(Color.background)
            .stroke(Color.primary)
            .frame(width: AngleDial.size, height: AngleDial.size)
            .overlay {
                ZStack {
                    DialSelectionShape(angle: angle.wrappedValue)
                        .fill(
                            .angularGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.accentColor
                                ],
                                center: .center,
                                startAngle: .zero,
                                endAngle: angle.wrappedValue
                            )
                        )
                    
                    DialKnobShape()
                        .rotation(angle.wrappedValue, anchor: .center)
                        .fill(Color.accentColor)
                        .stroke(Color.primary)
                }
                .clipShape(DialTrackShape())
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onDrag(to: value.location)
                    }
                    .onEnded { value in
                        onDragStopped(at: value.location)
                    }
            )
            .onTapGesture { location in
                updateAngle(from: location)
            }
    }
}

private extension AngleDial {
    static let size: CGFloat = 78
    
    func onDrag(to location: CGPoint) {
        let wasDragging = isDragging
        isDragging = true
        
        if !wasDragging {
            onBeginEditing()
        }

        updateAngle(from: location)
    }
    
    func onDragStopped(at location: CGPoint) {
        updateAngle(from: location)
        
        isDragging = false
        
        onEndEditing()
    }
    
    func updateAngle(from location: CGPoint) {
        let center = CGPoint(x: AngleDial.size / 2.0, y: AngleDial.size / 2.0)
        let zeroPoint = CGPoint(x: AngleDial.size, y: AngleDial.size / 2.0)
        
        let vectorA = Vector(start: center, end: zeroPoint)
        let vectorB = Vector(start: center, end: location)
        
        var newAngle = vectorA.angle(between: vectorB)
        if location.y < center.y {
            // It's greater than 180º so we'll need to manually add on
            newAngle = Angle(degrees: 360) - newAngle
        }
        angle.wrappedValue = newAngle
    }
}

struct DialTrackShape: Shape {    
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

struct DialSelectionShape: Shape {
    let angle: Angle
    
    func path(in rect: CGRect) -> Path {
        // Assume rotation around 0,0
        let zeroPoint = CGPoint(x: rect.width, y: 0.0)
        let middle = CGPoint(x: rect.midX, y: rect.midY)
        let zero = CGPoint(x: middle.x + zeroPoint.x, y: middle.y + zeroPoint.y)
        
        var triangle = Path()
        triangle.move(to: middle)
        triangle.addLine(to: zero)
        triangle.addArc(center: middle, radius: rect.width / 2.0, startAngle: .zero, endAngle: angle, clockwise: false)
        triangle.addLine(to: middle)
        triangle.closeSubpath()
        return triangle
    }
}

struct DialKnobShape: Shape {
    private static let knobSize: CGFloat = 16.0
    
    func path(in rect: CGRect) -> Path {
        let knobRect = CGRect(
            origin: CGPoint(
                x: rect.maxX - DialKnobShape.knobSize,
                y: rect.midY - DialKnobShape.knobSize / 2.0
            ),
            size: CGSize(
                width: DialKnobShape.knobSize,
                height: DialKnobShape.knobSize
            )
        )
        
        var triangle = Path()
        triangle.move(to: CGPoint(x: knobRect.minX, y: knobRect.midY))
        triangle.addLine(to: CGPoint(x: knobRect.maxX + 1, y: knobRect.minY))
        triangle.addLine(to: CGPoint(x: knobRect.maxX + 1, y: knobRect.maxY))
        triangle.addLine(to: CGPoint(x: knobRect.minX, y: knobRect.midY))
        triangle.closeSubpath()
        return triangle
    }
}

struct Vector {
    let start: CGPoint
    let end: CGPoint
    
    var length: CGFloat {
        let xDelta = (end.x - start.x)
        let yDelta = (end.y - start.y)
        return sqrt(xDelta * xDelta + yDelta * yDelta)
    }
    
    func dotProduct(_ b: Vector) -> CGFloat {
        // ax × bx + ay × by
        let ax = end.x - start.x
        let ay = end.y - start.y
        let bx = b.end.x - b.start.x
        let by = b.end.y - b.start.y
        return ax * bx + ay * by
    }
    
    func angle(between other: Vector) -> Angle {
        Angle(radians: acos(dotProduct(other) / (length * other.length)))
    }
}

struct AngleDialPreview: View {
    @State var angle: Angle = .init(degrees: 90)
    
    var body: some View {
        AngleDial(angle: $angle)
    }
}

#Preview {
    VStack {
        AngleDialPreview()
            .padding()
    }
}
