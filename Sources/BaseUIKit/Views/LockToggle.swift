import SwiftUI

public struct LockToggle: View {
    private let isOn: Binding<Bool>
    
    public init(isOn: Binding<Bool>) {
        self.isOn = isOn
    }
    
    public var body: some View {
        IconToggle(
            isOn: isOn,
            onImage: Image(systemName: "lock"),
            offImage: Image(systemName: "lock.open")
        )
    }
}

struct PreviewLockToggle: View {
    @State private var isOn = false
    
    var body: some View {
        LockToggle(isOn: $isOn)
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
