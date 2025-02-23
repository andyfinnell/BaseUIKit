import SwiftUI

public struct LockToggle: View {
    private let isOn: Bool
    private let onChange: (Bool) -> Void
    
    public init(isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.isOn = isOn
        self.onChange = onChange
    }
    
    public var body: some View {
        IconToggle(
            isOn: isOn,
            onChange: onChange,
            onImage: Image(systemName: "lock"),
            offImage: Image(systemName: "lock.open")
        )
    }
}

struct PreviewLockToggle: View {
    @State private var isOn = false
    
    var body: some View {
        LockToggle(isOn: isOn, onChange: { isOn = $0 })
    }
}

#Preview {
    VStack {
        HStack {
            PreviewLockToggle()
                .padding()
            
            Spacer()
        }
        Spacer()
    }
}
