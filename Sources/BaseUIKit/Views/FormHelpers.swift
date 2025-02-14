import SwiftUI
import BaseKit

public extension View {
    func formFieldValue() -> some View {
        labelsHidden()
            .fixedSize(horizontal: true, vertical: false)
    }
    
    func lastSectionRow() -> some View {
        #if os(macOS)
        padding(.bottom)
        #else
        self
        #endif
    }
    
    func formPadding() -> some View {
        #if os(macOS)
        padding()
        #else
        self
        #endif
    }
}

enum PreviewUnits: String, Hashable, CaseIterable {
    case inches
    case cm
    case px
}

struct PreviewLength {
    var value: Double
    var units: PreviewUnits
}

struct PreviewField: View {
    let title: String
    let value: Binding<PreviewLength>
    
    var body: some View {
        TextPickerField(
            title,
            value: value,
            text: BindingMap(
                get: { $0.value.formatted() },
                set: { PreviewLength(value: Double($1) ?? $0.value, units: $0.units)}),
            picker: BindingMap(\.units),
            pickerValues: PreviewUnits.allCases
        ) { pickerValue in
            Text(pickerValue.rawValue)
        }
    }
}

struct PreviewForm: View {
    @State private var anchor: BaseKit.AnchorPoint = .center
    @State private var keepAspectRatio: Bool = true
    @State private var width: PreviewLength = .init(value: 500, units: .px)
    @State private var height: PreviewLength = .init(value: 500, units: .px)

    var body: some View {
        Form {
            Section("Size") {
                LabeledContent("Width") {
                    PreviewField(title: "Width", value: $width)
                        .formFieldValue()
                }

                LabeledContent("Height") {
                    PreviewField(title: "Height", value: $height)
                        .formFieldValue()
                }

                Toggle("Keep aspect ratio", isOn: $keepAspectRatio)
                    .lastSectionRow()
            }
                        
            Section("Layout") {
                LabeledContent("Anchor") {
                    AnchorView($anchor)
                }
            }
        }
        .formPadding()
    }
}

#Preview {
    PreviewForm()
}
