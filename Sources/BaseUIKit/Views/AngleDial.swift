import SwiftUI
import BaseKit

public struct AngleDial: View {
    private let angle: SmartBind<BaseKit.Angle, ExtraEmpty>
    private let onBeginEditing: Callback<Void>
    private let onEndEditing: Callback<Void>
    @State private var isDragging = false

    public init(
        angle: BaseKit.Angle,
        onChange: @escaping (BaseKit.Angle) -> Void,
        onBeginEditing: @escaping () -> Void,
        onEndEditing: @escaping () -> Void
    ) {
        self.angle = SmartBind(angle, onChange)
        self.onBeginEditing = Callback(onBeginEditing)
        self.onEndEditing = Callback(onEndEditing)
    }

    init(
        angle: SmartBind<BaseKit.Angle, ExtraEmpty>,
        onBeginEditing: Callback<Void>,
        onEndEditing: Callback<Void>
    ) {
        self.angle = angle
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }

    public var body: some View {
        DialTrackShape()
            .fill(Color.background)
            .stroke(Color.primary, lineWidth: 3.0)
            .frame(width: AngleDial.size, height: AngleDial.size)
            .overlay {
                DialKnobShape()
                    .rotation(angle.value.toSwiftUI, anchor: .center)
                    .fill(Color.accentColor)
                    .stroke(Color.primary)
            }
            .gesture(
                DragGesture(minimumDistance: 3)
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
    static let size: CGFloat = 48
    
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
        angle.flush()
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
            newAngle = BaseKit.Angle(degrees: 360) - newAngle
        }
        angle.debounce(newAngle)
    }
}

struct DialTrackShape: Shape {    
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect.insetBy(dx: 6, dy: 6))
    }
}

struct DialKnobShape: Shape {
    private static let knobSize: CGFloat = 12.0
    
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
        
        return Path(ellipseIn: knobRect)
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
    
    func angle(between other: Vector) -> BaseKit.Angle {
        BaseKit.Angle(radians: acos(dotProduct(other) / (length * other.length)))
    }
}
