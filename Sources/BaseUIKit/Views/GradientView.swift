import SwiftUI
import BaseKit

public struct GradientView: View {
    public struct Stop: Equatable, Identifiable, Codable, Sendable {
        public let id: UUID
        public var offset: CGFloat
        public var color: BaseKit.Color
        
        public init(id: UUID, offset: CGFloat, color: BaseKit.Color) {
            self.id = id
            self.offset = offset
            self.color = color
        }
    }
    
    private let allStops: [[Stop]]
    @State private var width: CGFloat = 0.0
    @State private var removingStop: RemovingStop? = nil
    @State private var isDragging = false
    private let onChange: ([Stop]) -> Void
    private let onBeginEditing: () -> Void
    private let onEndEditing: () -> Void

    public init(
        stops: [Stop],
        onChange: @escaping ([Stop]) -> Void,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        self.allStops = [stops]
        self.onChange = onChange
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }
    
    public init<C: RandomAccessCollection & Sendable>(
        sources: C,
        stop: KeyPath<C.Element, [Stop]> & Sendable,
        onChange: @escaping ([Stop]) -> Void,
        onBeginEditing: @escaping () -> Void = {},
        onEndEditing: @escaping () -> Void = {}
    ) {
        allStops = sources.map { $0[keyPath: stop] }
        self.onChange = onChange
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
    }

    public var body: some View {
        VStack(spacing: 0) {
            if hasSingleSetOfStops {
                linearGradient
                colorStops
            } else {
                uniqueLinearGradients
                colorStopsBackground
            }
        }
    }
}

private extension GradientView {
    @ViewBuilder
    func linearGradientView(for stops: [Stop]) -> some View {
        LinearGradient(
            stops: stops.sorted(by: { $0.offset < $1.offset }).map {
                Gradient.Stop(color: $0.color.swiftUI, location: $0.offset)
            },
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    @ViewBuilder
    var linearGradient: some View {
        linearGradientView(for: stops)
        .frame(height: GradientView.totalGradientHeight)
        .onTapGesture { location in
            insertStop(at: location, inWidth: width)
        }
    }
    
    @ViewBuilder
    var colorStops: some View {
        colorStopsBackground
            .onTapGesture { location in
                insertStop(at: location, inWidth: width)
            }
            .overlay {
                GeometryReader { geometry in
                    ForEach(stops) { stop in
                        colorStop(for: stop, width: geometry.size.width)
                    }
                    .onChange(of: geometry.size.width, initial: true) { _, new in
                        self.width = new
                    }
                }
            }
    }
    
    @ViewBuilder
    func colorStop(for stop: Stop, width: CGFloat) -> some View {
        ColorChip(
            color: stop.color,
            onChange: {
                var newValue = stops
                newValue[byID: stop.id] = Stop(id: stop.id, offset: stop.offset, color: $0)
                onChange(newValue)
            },
            onBeginEditing: onBeginEditing,
            onEndEditing: onEndEditing
        )
        .background(alignment: .top) {
            if let removingStop, removingStop.id == stop.id {
                VStack {
                    ColorChip(
                        color: BaseKit.Color.black,
                        onChange: { _ in },
                        onBeginEditing: onBeginEditing,
                        onEndEditing: onEndEditing
                    )
                    .hidden()
                    
                    RemoveTag()
                        .fixedSize()
                }
            }
        }
        .position(stopLocation(stop, width: width))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragStop(stop, to: value.location, width: width)
                }
                .onEnded { value in
                    dragStopFinished(stop, to: value.location, width: width)
                }
        )
    }
    
    @ViewBuilder
    var colorStopsBackground: some View {
        Color.secondary
            .frame(height: ColorChip.bodyHeight)
    }

    @ViewBuilder
    var uniqueLinearGradients: some View {
        ForEach(presentedStops.indices, id: \.self) { index in
            linearGradientView(for: presentedStops[index])
            .frame(height: setOfStopsHeight)
            .onTapGesture {
                let newValue = presentedStops[index]
                onChange(newValue)
            }
        }
    }
    
    static let defaultStops: [GradientView.Stop] = [
        GradientView.Stop(id: UUID(), offset: 0.0, color: .white),
        GradientView.Stop(id: UUID(), offset: 1.0, color: .black),
    ]
    
    var stops: [Stop] {
        if let stop = allStops.only {
            return stop
        } else {
            return allStops.first ?? GradientView.defaultStops
        }
    }
    
    var hasSingleSetOfStops: Bool {
        uniqueStops.count == 1
    }
    
    var uniqueStops: [[Stop]] {
        var unique = [[Stop]]()
        for stop in allStops {
            let haveEquivalent = unique.contains { $0.isEquivalent(to: stop) }
            guard !haveEquivalent else {
                continue
            }
            unique.append(stop)
        }
        return unique
    }
    
    var presentedStops: [[Stop]] {
        let unique = uniqueStops
        let max = maximumSetOfStops
        if unique.count <= max {
            return unique
        } else {
            return Array(unique[0..<max])
        }
    }
    
    var setOfStopsHeight: CGFloat {
        let setCount = presentedStops.count
        return GradientView.totalGradientHeight / CGFloat(setCount)
    }

    static let totalGradientHeight: CGFloat = 44.0
    static let minimumGradientHeight: CGFloat = 11
    
    var maximumSetOfStops: Int {
        Int(floor(GradientView.totalGradientHeight / GradientView.minimumGradientHeight))
    }
    
    func insertStop(at location: CGPoint, inWidth width: CGFloat) {
        let offset = clamp(location.x / width, 0.0, 1.0)
        let stops = stops.sorted(by: { $0.offset < $1.offset })
        if let insertIndex = stops.firstIndex(where: { $0.offset > offset }) {
            let previousStop = stops.at(insertIndex - 1) ?? stops.first
            let nextStop = stops.at(insertIndex) ?? stops.last
            
            let previousOffset = previousStop?.offset ?? 0.0
            let previousColor = previousStop?.color ?? .black
            
            let nextOffset = nextStop?.offset ?? 1.0
            let nextColor = nextStop?.color ?? .white
            
            let parameter = (offset - previousOffset) / (nextOffset - previousOffset)
            let newColor = previousColor.linearInterpolate(at: parameter, to: nextColor)
            
            let newStop = GradientView.Stop(
                id: UUID(),
                offset: offset,
                color: newColor
            )
            
            var newStops = stops
            newStops.insert(newStop, at: insertIndex)
            onChange(newStops)
        } else {
            // append and just re-use the last
            let newStop = GradientView.Stop(
                id: UUID(),
                offset: offset,
                color: stops.last?.color ?? .black
            )
            var newStops = stops
            newStops.append(newStop)
            onChange(newStops)
        }
    }
    
    struct RemovingStop: Equatable {
        let id: UUID
        let location: CGPoint
    }
    
    func dragStop(_ stop: Stop, to location: CGPoint, width: CGFloat) {
        guard isEditable(stop) else {
            return
        }
        
        let wasDragging = isDragging
        isDragging = true
        
        if !wasDragging {
            onBeginEditing()
        }
        
        if isRemoving(location: location, width: width) {
            self.removingStop = RemovingStop(
                id: stop.id,
                location: location
            )
        } else {
            self.removingStop = nil
            
            var newStops = stops
            newStops[byID: stop.id] = Stop(
                id: stop.id,
                offset: clamp(location.x / width, 0.0, 1.0),
                color: stop.color
            )
            onChange(newStops)
        }
    }
    
    func dragStopFinished(_ stop: Stop, to location: CGPoint, width: CGFloat) {
        guard isEditable(stop) else {
            return
        }

        if isRemoving(location: location, width: width) {
            var newStops = stops
            newStops.removeAll(where: { $0.id == stop.id })
            onChange(newStops)
        } else {
            var newStops = stops
            newStops[byID: stop.id] = Stop(
                id: stop.id,
                offset: clamp(location.x / width, 0.0, 1.0),
                color: stop.color
            )
            onChange(newStops)
        }
        self.removingStop = nil
        isDragging = false
        
        onEndEditing()
    }
    
    func isRemoving(location: CGPoint, width: CGFloat) -> Bool {
        let chipSize = ColorChip.bodyHeight
        let halfChipSize = chipSize / 2.0
        return (location.x < -halfChipSize) || (location.x > (width + halfChipSize))
        || (location.y < -halfChipSize) || (location.y > (chipSize + halfChipSize))
    }
    
    func stopLocation(_ stop: Stop, width: CGFloat) -> CGPoint {
        if let removingStop, removingStop.id == stop.id {
            return removingStop.location
        } else {
            return CGPoint(
                x: stop.offset * width,
                y: ColorChip.centerYOffset
            )
        }
    }
    
    func isEditable(_ stop: Stop) -> Bool {
        // Need a minimum of two, first and last can't be moved from 0, 1
        let sorted = stops.sorted(by: { $0.offset < $1.offset })
        let isFirst = sorted.first?.id == stop.id
        let isLast = sorted.last?.id == stop.id
        return !isFirst && !isLast
    }
}
 
public extension GradientView.Stop {
    func isEquivalent(to other: GradientView.Stop) -> Bool {
        offset == other.offset && color == other.color
    }
    
    func equivalentHash(into hasher: inout Hasher) {
        hasher.combine(offset)
        hasher.combine(color)
    }
}

public extension Array where Element == GradientView.Stop {
    func isEquivalent(to other: [GradientView.Stop]) -> Bool {
        count == other.count && zip(self, other).allSatisfy { $0.isEquivalent(to: $1) }
    }
    
    func equivalentHash(into hasher: inout Hasher) {
        for element in self {
            element.equivalentHash(into: &hasher)
        }
    }
}

private extension Binding where Value == [GradientView.Stop] {
    func isEquivalent(to other: Binding<[GradientView.Stop]>) -> Bool {
        wrappedValue.isEquivalent(to: other.wrappedValue)
    }
}

private struct GradientViewPreview: View {
    @State var stops: [GradientView.Stop] = [
        GradientView.Stop(id: UUID(), offset: 0.0, color: .white),
        GradientView.Stop(id: UUID(), offset: 1.0, color: .black),
    ]
    
    var body: some View {
        GradientView(stops: stops, onChange: { stops = $0 })
            .frame(width: 320)
    }
}

private struct GradientViewMultiselectPreview: View {
    @State var stops: [[GradientView.Stop]] = [
        [
            GradientView.Stop(id: UUID(), offset: 0.0, color: .white),
            GradientView.Stop(id: UUID(), offset: 1.0, color: .black),
        ],
        [
            GradientView.Stop(id: UUID(), offset: 0.0, color: .red),
            GradientView.Stop(id: UUID(), offset: 0.5, color: .green),
            GradientView.Stop(id: UUID(), offset: 1.0, color: .blue),
        ],
        [
            GradientView.Stop(id: UUID(), offset: 0.0, color: .white),
            GradientView.Stop(id: UUID(), offset: 1.0, color: .black),
        ],
        [
            GradientView.Stop(id: UUID(), offset: 0.0, color: .yellow),
            GradientView.Stop(id: UUID(), offset: 1.0, color: .orange),
        ],

    ]
    
    var body: some View {
        GradientView(sources: stops, stop: \.self, onChange: { stops = [$0] })
            .frame(width: 320)
    }
}

#Preview {
    VStack {
        GradientViewPreview()
            .padding()
        
        GradientViewMultiselectPreview()
            .padding()
    }
}

public extension Array where Element == GradientView.Stop {
    func makeEquivalentStops(basedOn existingStops: [GradientView.Stop]) -> [GradientView.Stop] {
        var equivalentStops = [GradientView.Stop]()

        var remainingNewStops = [GradientView.Stop]()
        var remainingExistingStops = existingStops
        for newStop in self {
            if remainingExistingStops.contains(where: { $0.id == newStop.id }) {
                equivalentStops.append(newStop)
                remainingExistingStops.removeAll(where: { $0.id == newStop.id })
            } else {
                remainingNewStops.append(newStop)
            }
        }
        
        for newStop in remainingNewStops {
            if let nextExisting = remainingExistingStops.first {
                remainingExistingStops.removeFirst()
                
                equivalentStops.append(GradientView.Stop(id: nextExisting.id, offset: newStop.offset, color: newStop.color))
            } else {
                equivalentStops.append(GradientView.Stop(id: UUID(), offset: newStop.offset, color: newStop.color))
            }
        }
        
        equivalentStops.sort { $0.offset < $1.offset }
        
        return equivalentStops
    }

}
