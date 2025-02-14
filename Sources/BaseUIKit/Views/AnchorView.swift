import SwiftUI
import BaseKit

@MainActor
public struct AnchorView: View {
    private let anchor: Binding<BaseKit.AnchorPoint>
    
    public init(_ anchor: Binding<BaseKit.AnchorPoint>) {
        self.anchor = anchor
    }
    
    public var body: some View {
        Grid {
            GridRow {
                AnchorRadioButton(anchor: anchor, value: .topLeft)
                AnchorRadioButton(anchor: anchor, value: .topCenter)
                AnchorRadioButton(anchor: anchor, value: .topRight)
            }

            GridRow {
                AnchorRadioButton(anchor: anchor, value: .centerLeft)
                AnchorRadioButton(anchor: anchor, value: .center)
                AnchorRadioButton(anchor: anchor, value: .centerRight)
            }

            GridRow {
                AnchorRadioButton(anchor: anchor, value: .bottomLeft)
                AnchorRadioButton(anchor: anchor, value: .bottomCenter)
                AnchorRadioButton(anchor: anchor, value: .bottomRight)
            }
        }
    }
}

private struct AnchorRadioButton: View {
    var anchor: Binding<BaseKit.AnchorPoint>
    let value: BaseKit.AnchorPoint
    
    var body: some View {
        Button {
            anchor.wrappedValue = value
        } label: {
            Image(systemName: "photo")
                .isHidden(anchor.wrappedValue != value)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        switch value {
        case .topLeft:
            "top left"
        case .topCenter:
            "top"
        case .topRight:
            "top right"
        case .centerLeft:
            "middle left"
        case .center:
            "middle"
        case .centerRight:
            "middle right"
        case .bottomLeft:
            "bottom left"
        case .bottomCenter:
            "bottom"
        case .bottomRight:
            "bottom right"
        }
    }
}

struct TestAnchorView: View {
    @State var anchor: BaseKit.AnchorPoint = .center
    
    var body: some View {
        AnchorView($anchor)
    }
}

#Preview {
    TestAnchorView()
        .padding()
}
