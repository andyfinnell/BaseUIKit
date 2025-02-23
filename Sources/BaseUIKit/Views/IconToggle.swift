import SwiftUI

public struct IconToggle: View {
    private let isOn: Bool
    private let onChange: (Bool) -> Void
    private let onImage: Image
    private let offImage: Image
    
    public init(isOn: Bool, onChange: @escaping (Bool) -> Void, onImage: Image, offImage: Image) {
        self.isOn = isOn
        self.onChange = onChange
        self.onImage = onImage
        self.offImage = offImage
    }
    
    public var body: some View {
        Button(
            action: { onChange(!isOn) },
            label: {
                // Don't change size when toggling
                ZStack {
                    onImage
                        .isHidden(!isOn)
                    offImage
                        .isHidden(isOn)
                }
            }
        ).buttonStyle(.borderless)
    }
}
