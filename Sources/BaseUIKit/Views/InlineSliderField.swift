import SwiftUI

public protocol SliderFieldParser<Value>: FieldParser {
    static func doubleValue(_ value: Value) -> Double
    static func fromDoubleValue(_ number: Double, existing: Value) -> Value
}

public struct InlineSliderField<Parser: SliderFieldParser>: View {
    private let title: String
    private let value: SmartBind<Parser.Value, ExtraEmpty>
    private let range: ClosedRange<Double>
    private let step: Double?
    private let defaultSliderValue: Double?
    /// Per-source double positions used to render small markers on the
    /// track when the selection is in the mixed sentinel state. Empty in
    /// single-source contexts; otherwise one entry per source element,
    /// pre-converted via `Parser.doubleValue`.
    private let markers: [Double]
    private let onBeginEditing: Callback<Void>
    private let onEndEditing: Callback<Void>
    @State private var errorMessage: String?
    @State private var text: String = ""
    @State private var number: Double = 0.0
    @State private var isTextEditing = false
    @FocusState private var isFocused: Bool

    public init(
        _ title: String,
        value: Parser.Value,
        onChange: @escaping (Parser.Value) -> Void,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        defaultSliderValue: Double? = nil,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = SmartBind(value, onChange)
        self.range = range
        self.step = step
        self.defaultSliderValue = defaultSliderValue
        self.markers = []
        self.onBeginEditing = Callback(onBeginEditing)
        self.onEndEditing = Callback(onEndEditing)
        self.errorMessage = errorMessage
    }

    public init(
        _ title: String,
        value: Binding<Parser.Value>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        defaultSliderValue: Double? = nil,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.init(
            title,
            value: value.wrappedValue,
            onChange: { value.wrappedValue = $0 },
            in: range,
            step: step,
            defaultSliderValue: defaultSliderValue,
            errorMessage: errorMessage,
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
    }

    init(
        _ title: String,
        value: SmartBind<Parser.Value, ExtraEmpty>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        defaultSliderValue: Double? = nil,
        markers: [Double] = [],
        errorMessage: String? = nil,
        onBeginEditing: Callback<Void>,
        onEndEditing: Callback<Void>
    ) {
        self.title = title
        self.value = value
        self.range = range
        self.step = step
        self.defaultSliderValue = defaultSliderValue
        self.markers = markers
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
        self.errorMessage = errorMessage
    }

    public init<C: RandomAccessCollection & Sendable>(
        _ title: String,
        sources: C,
        value: KeyPath<C.Element, Parser.Value> & Sendable,
        onChange: @escaping (Parser.Value) -> Void,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        defaultSliderValue: Double? = nil,
        errorMessage: String? = nil,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = SmartBind(
            Parser.multiselectValue(sources: sources, value: value), onChange)
        self.range = range
        self.step = step
        self.defaultSliderValue = defaultSliderValue
        self.markers = sources.map { Parser.doubleValue($0[keyPath: value]) }
        self.onBeginEditing = Callback(onBeginEditing)
        self.onEndEditing = Callback(onEndEditing)
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack {
            HStack {
                slider
                    .frame(minWidth: 80)

                TextField(
                    text: $text,
                    prompt: Text(promptText),
                    label: {
                        Text(title)
                            .multilineTextAlignment(.trailing)
                    }
                )
                .focused($isFocused)
                .onSubmit {
                    endTextEditingIfNecessary()
                }
#if os(macOS)
                .textFieldStyle(.squareBorder)
                .frame(width: 50)
#endif
#if os(iOS)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .frame(width: 60)
#endif
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.leading)
                .labelsHidden()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
        .onChange(of: value.value, initial: true) { oldValue, newValue in
            text = expectedTextForCurrentValue(newValue)
            number = resolvedSliderValue(for: newValue)
        }
        .onChange(of: text) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            // Skip the write-back when this text update was driven by a
            // change to `value.value` rather than by user typing. The
            // tell: the current text matches what we'd render
            // programmatically for `value.value`. (Same-value user
            // typings are no-ops anyway because `hasChanged` returns
            // false, so skipping is safe.)
            //
            // Without this guard, lossy format/parse round-trips of a
            // multi-select sentinel write spurious values back to the
            // model. See `AppearancePanelUITests
            // .testExtendingSelectionDoesNotClobberOpacity`.
            if newValue == expectedTextForCurrentValue(value.value) {
                errorMessage = nil
                return
            }

            switch Parser.parseValue(newValue) {
            case let .success(newValue):
                if Parser.hasChanged(value.value, newValue) {
                    beginTextEditingIfNecessary()
                    value.onChange(newValue)
                }
                errorMessage = nil
            case let .failure(error):
                errorMessage = error.message
            }
        }
        .onChange(of: number) { oldValue, newValue in
            guard !newValue.isClose(to: oldValue, threshold: 1e-6) else {
                return
            }
            // Skip the write-back when the slider state was driven by a
            // change to `value.value` rather than the user dragging the
            // slider. The tell: `number` matches what
            // `resolvedSliderValue(for: value.value)` would compute.
            // This catches the same lossy round-trip the text-onChange
            // guard catches: when `value.value` is a non-finite
            // multi-select sentinel, `resolvedSliderValue` collapses it
            // to `range.lowerBound` (typically 0), and without this
            // guard the slider's number-onChange would write that 0
            // back to the model.
            if newValue.isClose(
                to: resolvedSliderValue(for: value.value), threshold: 1e-6)
            {
                return
            }

            let parsedValue = Parser.fromDoubleValue(newValue, existing: value.value)
            if Parser.hasChanged(value.value, parsedValue) {
                value.onChange(parsedValue)
            }
            text = Parser.formatValue(parsedValue)
        }
        .onChange(of: isFocused) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            if !newValue {
                endTextEditingIfNecessary()
            }
        }
    }
}

private extension InlineSliderField {
    /// The slider control. In mixed-value state, swaps to a fully custom
    /// view (`mixedSlider`) showing a thin track with one marker dot per
    /// selected element's actual value — no misleading "thumb at zero."
    /// The custom view stays interactive via a `DragGesture` (dragging
    /// anywhere on the track writes a uniform value to every selected
    /// element, collapsing the mixed state). For accessibility / XCUI,
    /// `.accessibilityRepresentation` wraps the custom view so it shows
    /// up as a real `Slider` element to assistive tech and to
    /// `XCUIElement.adjust(toNormalizedSliderPosition:)`.
    @ViewBuilder
    var slider: some View {
        if Parser.isMixedSentinel(value.value), !markers.isEmpty {
            mixedSlider
        } else {
            standardSlider
        }
    }

    var standardSlider: some View {
        Slider(
            value: $number,
            in: range,
            step: resolvedStep,
            onEditingChanged: { isEditing in
                if isEditing {
                    onBeginEditing()
                } else {
                    onEndEditing()
                }
            }
        )
        .controlSize(.mini)
    }

    var mixedSlider: some View {
        // The mixed-state gesture writes a single value per tap (or per
        // drag tick) directly via `value.onChange`, with NO surrounding
        // `onBeginEditing`/`onEndEditing` wrap. Rationale: the first
        // write collapses `value.value` out of the mixed sentinel state,
        // which removes this branch from the view tree on the next
        // render. SwiftUI cancels gestures on removed views, so an
        // `onEnded` paired with an `onBeginEditing` would orphan the
        // command stream — `completeCommandStream` would never fire and
        // the command would never be registered with the undo manager.
        // Using plain `performCommand` per write side-steps that: each
        // tap is one normal undoable step.
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 3)

                ForEach(Array(markers.enumerated()), id: \.offset) { _, marker in
                    let normalized = normalizedPosition(for: marker)
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .position(
                            x: normalized * proxy.size.width,
                            y: proxy.size.height / 2
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        writeMixedSliderValue(
                            atX: drag.location.x, trackWidth: proxy.size.width)
                    }
            )
        }
        .frame(height: 16)
        .accessibilityRepresentation {
            Slider(
                value: Binding<Double>(
                    get: { number },
                    set: { newValue in
                        let parsed = Parser.fromDoubleValue(
                            newValue, existing: value.value)
                        if Parser.hasChanged(value.value, parsed) {
                            value.onChange(parsed)
                        }
                    }
                ),
                in: range,
                step: resolvedStep
            )
        }
    }

    func writeMixedSliderValue(atX x: Double, trackWidth: Double) {
        guard trackWidth > 0 else { return }
        let progress = max(0, min(1, x / trackWidth))
        let span = range.upperBound - range.lowerBound
        let raw = range.lowerBound + progress * span
        let stepped: Double
        if resolvedStep > 0 {
            stepped = range.lowerBound
                + round((raw - range.lowerBound) / resolvedStep) * resolvedStep
        } else {
            stepped = raw
        }
        let parsed = Parser.fromDoubleValue(stepped, existing: value.value)
        if Parser.hasChanged(value.value, parsed) {
            value.onChange(parsed)
        }
    }

    func normalizedPosition(for value: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return max(0, min(1, (value - range.lowerBound) / span))
    }

    /// What `text` should hold for the given parser value, accounting
    /// for the mixed sentinel case. The "is this update programmatic?"
    /// guard above compares the text-change against this.
    func expectedTextForCurrentValue(_ value: Parser.Value) -> String {
        Parser.isMixedSentinel(value) ? "" : Parser.formatValue(value)
    }

    var promptText: String {
        Parser.isMixedSentinel(value.value) ? "Mixed" : title
    }

    var resolvedStep: Double {
        step ?? (range.upperBound - range.lowerBound) / 200.0
    }

    func resolvedSliderValue(for parserValue: Parser.Value) -> Double {
        let parsed = Parser.doubleValue(parserValue)
        if parsed.isFinite {
            return parsed
        }
        return defaultSliderValue ?? range.lowerBound
    }

    func beginTextEditingIfNecessary() {
        guard isFocused && !isTextEditing else {
            return
        }
        isTextEditing = true
        onBeginEditing()
    }

    func endTextEditingIfNecessary() {
        guard isTextEditing else {
            return
        }
        isTextEditing = false
        onEndEditing()
    }
}
