import SwiftUI

public struct TextPickerField<Value, PickerValue: Hashable, PickerContent: View>: View {
    let title: String
    let value: Binding<Value>
    let textMap: BindingMap<Value, String>
    let pickerMap: BindingMap<Value, PickerValue>
    let pickerValues: [PickerValue]
    let pickerValueContent: (PickerValue) -> PickerContent
    
    public init(
        _ title: String,
        value: Binding<Value>,
        text: BindingMap<Value, String>,
        picker: BindingMap<Value, PickerValue>,
        pickerValues: [PickerValue],
        @ViewBuilder pickerValueContent: @escaping (PickerValue) -> PickerContent
    ) {
        self.title = title
        self.value = value
        self.textMap = text
        self.pickerMap = picker
        self.pickerValues = pickerValues
        self.pickerValueContent = pickerValueContent
    }
    
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            TextField(
                title,
                text: value.map(textMap),
                prompt: Text(title)
            )
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.trailing)
            .frame(idealWidth: 120, maxWidth: 120)
            
            Picker("", selection: value.map(pickerMap)) {
                ForEach(pickerValues, id: \.self) { value in
                    pickerValueContent(value)
                            .tag(value)
                }
            }
            
        }
    }
}
