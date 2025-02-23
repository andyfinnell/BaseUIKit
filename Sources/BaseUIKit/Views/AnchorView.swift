import SwiftUI
import BaseKit

public struct AnchorView: View {
    private let anchor: BaseKit.AnchorPoint
    private let onChange: (BaseKit.AnchorPoint) -> Void
    
    public init(anchor: BaseKit.AnchorPoint, onChange: @escaping (BaseKit.AnchorPoint) -> Void) {
        self.anchor = anchor
        self.onChange = onChange
    }
    
    public var body: some View {
        Grid {
            GridRow {
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .topLeft)
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .topCenter)
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .topRight)
            }

            GridRow {
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .centerLeft)
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .center)
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .centerRight)
            }

            GridRow {
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .bottomLeft)
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .bottomCenter)
                AnchorRadioButton(anchor: anchor, onChange: onChange, represents: .bottomRight)
            }
        }
    }
}

private struct AnchorRadioButton: View {
    let anchor: BaseKit.AnchorPoint
    let onChange: (BaseKit.AnchorPoint) -> Void
    let represents: BaseKit.AnchorPoint
    
    var body: some View {
        Button {
            onChange(represents)
        } label: {
            Image(systemName: "photo")
                .isHidden(anchor != represents)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        switch represents {
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
        AnchorView(anchor: anchor, onChange: { anchor = $0 })
    }
}

#Preview {
    TestAnchorView()
        .padding()
}
