import SwiftUI
import BaseKit

public struct AnchorButton: View {
    private let action: Callback<BaseKit.AnchorPoint>
    @State private var showPopover = false
    
    public init(action: @escaping (BaseKit.AnchorPoint) -> Void) {
        self.action = Callback(action)
    }

    public var body: some View {
        Button(action: {
            showPopover.toggle()
        }, label: {
            Label("Anchor", systemImage: "square.grid.3x3")
        })
        .labelStyle(.iconOnly)
        .popover(isPresented: $showPopover) {
            AnchorPopOver {
                showPopover = false
                action($0)
            }
        }
    }
}

private struct AnchorPopOver: View {
    private let action: Callback<BaseKit.AnchorPoint>
    
    init(action: @escaping (BaseKit.AnchorPoint) -> Void) {
        self.action = Callback(action)
    }
    
    var body: some View {
        Grid {
            GridRow {
                AnchorPopOverButton(value: .topLeft, action: action)
                AnchorPopOverButton(value: .topCenter, action: action)
                AnchorPopOverButton(value: .topRight, action: action)
            }

            GridRow {
                AnchorPopOverButton(value: .centerLeft, action: action)
                AnchorPopOverButton(value: .center, action: action)
                AnchorPopOverButton(value: .centerRight, action: action)
            }

            GridRow {
                AnchorPopOverButton(value: .bottomLeft, action: action)
                AnchorPopOverButton(value: .bottomCenter, action: action)
                AnchorPopOverButton(value: .bottomRight, action: action)
            }
        }
    }
}

private struct AnchorPopOverButton: View {
    private static let size: CGFloat = 24
    
    let value: BaseKit.AnchorPoint
    let action: Callback<BaseKit.AnchorPoint>
    
    var body: some View {
        Button(
            action: { action(value) },
            label: {
                AnchorShape(value: value)
                    .fill(Color.primary)
                    .frame(width: AnchorPopOverButton.size, height: AnchorPopOverButton.size)
            }
        )
        .buttonStyle(.borderless)
    }
}

private struct AnchorShape: Shape {
    let value: BaseKit.AnchorPoint

    func path(in rect: CGRect) -> Path {
        switch value {
        case .topLeft:
            topLeft(in: rect)
        case .topCenter:
            top(in: rect)
        case .topRight:
            topRight(in: rect)
        case .centerLeft:
            middleLeft(in: rect)
        case .center:
            middle(in: rect)
        case .centerRight:
            middleRight(in: rect)
        case .bottomLeft:
            bottomLeft(in: rect)
        case .bottomCenter:
            bottom(in: rect)
        case .bottomRight:
            bottomRight(in: rect)
        }
    }
}

private extension AnchorShape {
    func topLeft(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.midX, to: rect.maxX, in: rect)
        path.addVerticalLine(from: rect.midY, to: rect.maxY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func top(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.minX, to: rect.maxX, in: rect)
        path.addVerticalLine(from: rect.midY, to: rect.maxY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func topRight(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.minX, to: rect.midX, in: rect)
        path.addVerticalLine(from: rect.midY, to: rect.maxY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func middleLeft(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.midX, to: rect.maxX, in: rect)
        path.addVerticalLine(from: rect.minY, to: rect.maxY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func middle(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.minX, to: rect.maxX, in: rect)
        path.addVerticalLine(from: rect.minY, to: rect.maxY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func middleRight(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.minX, to: rect.midX, in: rect)
        path.addVerticalLine(from: rect.minY, to: rect.maxY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func bottomLeft(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.midX, to: rect.maxX, in: rect)
        path.addVerticalLine(from: rect.minY, to: rect.midY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func bottom(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.minX, to: rect.maxX, in: rect)
        path.addVerticalLine(from: rect.minY, to: rect.midY, in: rect)
        path.addDot(in: rect)
        return path
    }

    func bottomRight(in rect: CGRect) -> Path {
        var path = Path()
        path.addHorizontalLine(from: rect.minX, to: rect.midX, in: rect)
        path.addVerticalLine(from: rect.minY, to: rect.midY, in: rect)
        path.addDot(in: rect)
        return path
    }
}

private extension Path {
    private static let lineWidth: CGFloat = 1
    private static let circleDiameter: CGFloat = 9

    mutating func addHorizontalLine(
        from startX: CGFloat,
        to endX: CGFloat,
        in rect: CGRect
    ) {
        addRect(
            CGRect(
                x: startX,
                y: rect.midY - Path.lineWidth / 2.0,
                width: endX - startX,
                height: Path.lineWidth
            )
        )
    }
    
    mutating func addVerticalLine(
        from startY: CGFloat,
        to endY: CGFloat,
        in rect: CGRect
    ) {
        addRect(
            CGRect(
                x: rect.midX - Path.lineWidth / 2.0,
                y: startY,
                width: Path.lineWidth,
                height: endY - startY
            )
        )
    }
    
    mutating func addDot(in rect: CGRect) {
        addEllipse(
            in: CGRect(
                x: rect.midX - Path.circleDiameter / 2.0,
                y: rect.midY - Path.circleDiameter / 2.0,
                width: Path.circleDiameter,
                height: Path.circleDiameter
            )
        )
    }
}

struct PreviewAnchorButton: View {
    var body: some View {
        AnchorButton(action: { print("\($0)") })
    }
}

#Preview {
    VStack {
        HStack {
            PreviewAnchorButton()
                .padding()
            
            Spacer()
        }
        
        Spacer()
    }
}
