import SwiftUI

public struct InspectorGroup<Content: View>: View {
    private let title: String
    private let key: String
    private let content: () -> Content
    @State private var isExpanded = false
    @Environment(\.documentFileURLHash) private var documentFileURLHash
    
    public init(_ title: String, key: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.key = key
        self.content = content
    }
    
    public var body: some View {
#if os(macOS)
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                content()
                    .controlSize(.mini)
                    .padding()
            }, label: {
                Text(title)
            }
        )
        .disclosureGroupStyle(InspectorDisclosureStyle())
        .onAppear {
            isExpanded = shouldBeVisible
        }
        .onChange(of: isExpanded) { oldValue, newValue in
            shouldBeVisible = newValue
        }

#else
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                content()
                    .controlSize(.mini)
                    .padding()
            }, label: {
                Text(title)
            }
        )
        .disclosureGroupStyle(InspectorDisclosureStyle())
        .onAppear {
            isExpanded = shouldBeVisible
        }
        .onChange(of: isExpanded) { oldValue, newValue in
            shouldBeVisible = newValue
        }
#endif
    }
}

private extension InspectorGroup {
    var userDefaultsKey: String {
        if let documentFileURLHash {
            "\(documentFileURLHash).\(key).inspector.isVisible"
        } else {
            "\(key).inexpector.isVisible"
        }
    }
    
    var shouldBeVisible: Bool {
        get {
            UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
        
        nonmutating set {
            if newValue == false {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            } else {
                UserDefaults.standard.set(true, forKey: userDefaultsKey)
            }
        }
    }
}

struct InspectorDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.accentColor)
                        .animation(nil, value: configuration.isExpanded)

                    configuration.label
                        .foregroundColor(.accentColor)

                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .background(Color.background)
            #else
            .background(Color.secondaryBackground)
            #endif
            
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
