import SwiftUI

public struct IconToggle: View {
    private let isOn: Binding<Bool>
    private let onImage: Image
    private let offImage: Image
    
    public init(isOn: Binding<Bool>, onImage: Image, offImage: Image) {
        self.isOn = isOn
        self.onImage = onImage
        self.offImage = offImage
    }
    
    public var body: some View {
        Button(
            action: { isOn.wrappedValue.toggle() },
            label: {
                // Don't change size when toggling
                ZStack {
                    onImage
                        .isHidden(!isOn.wrappedValue)
                    offImage
                        .isHidden(isOn.wrappedValue)
                }
            }
        ).buttonStyle(.borderless)
    }
}
