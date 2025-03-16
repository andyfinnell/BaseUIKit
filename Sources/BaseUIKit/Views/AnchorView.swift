import SwiftUI
import BaseKit

public struct AnchorView: View {
    private let anchor: SmartBind<BaseKit.AnchorPoint, ExtraEmpty>
    
    public init(anchor: BaseKit.AnchorPoint, onChange: @escaping (BaseKit.AnchorPoint) -> Void) {
        self.anchor = SmartBind(anchor, onChange)
    }
    
    public var body: some View {
        Grid {
            GridRow {
                AnchorRadioButton(anchor: anchor, represents: .topLeft)
                AnchorRadioButton(anchor: anchor, represents: .topCenter)
                AnchorRadioButton(anchor: anchor, represents: .topRight)
            }

            GridRow {
                AnchorRadioButton(anchor: anchor, represents: .centerLeft)
                AnchorRadioButton(anchor: anchor, represents: .center)
                AnchorRadioButton(anchor: anchor, represents: .centerRight)
            }

            GridRow {
                AnchorRadioButton(anchor: anchor, represents: .bottomLeft)
                AnchorRadioButton(anchor: anchor, represents: .bottomCenter)
                AnchorRadioButton(anchor: anchor, represents: .bottomRight)
            }
        }
    }
}

private struct AnchorRadioButton: View {
    let anchor: SmartBind<BaseKit.AnchorPoint, ExtraEmpty>
    let represents: BaseKit.AnchorPoint
    
    var body: some View {
        Button {
            anchor.onChange(represents)
        } label: {
            Image(systemName: "photo")
                .isHidden(anchor.value != represents)
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
