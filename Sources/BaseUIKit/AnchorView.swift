import SwiftUI

@MainActor
public struct AnchorView: View {
    public enum Anchor: Hashable, Sendable {
        case topLeft
        case top
        case topRight
        case middleLeft
        case middle
        case middleRight
        case bottomLeft
        case bottom
        case bottomRight
    }
    
    let anchor: Binding<Anchor>
    
    public init(_ anchor: Binding<Anchor>) {
        self.anchor = anchor
    }
    
    public var body: some View {
        Grid {
            GridRow {
                AnchorButton(anchor: anchor, value: .topLeft)
                AnchorButton(anchor: anchor, value: .top)
                AnchorButton(anchor: anchor, value: .topRight)
            }

            GridRow {
                AnchorButton(anchor: anchor, value: .middleLeft)
                AnchorButton(anchor: anchor, value: .middle)
                AnchorButton(anchor: anchor, value: .middleRight)
            }

            GridRow {
                AnchorButton(anchor: anchor, value: .bottomLeft)
                AnchorButton(anchor: anchor, value: .bottom)
                AnchorButton(anchor: anchor, value: .bottomRight)
            }
        }
    }
}

private struct AnchorButton: View {
    var anchor: Binding<AnchorView.Anchor>
    let value: AnchorView.Anchor
    
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
        case .top:
            "top"
        case .topRight:
            "top right"
        case .middleLeft:
            "middle left"
        case .middle:
            "middle"
        case .middleRight:
            "middle right"
        case .bottomLeft:
            "bottom left"
        case .bottom:
            "bottom"
        case .bottomRight:
            "bottom right"
        }
    }
}

struct TestAnchorView: View {
    @State var anchor: AnchorView.Anchor = .middle
    
    var body: some View {
        AnchorView($anchor)
    }
}

#Preview {
    TestAnchorView()
        .padding()
}
