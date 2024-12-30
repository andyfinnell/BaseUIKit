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
    
    private let allStops: [Binding<[Stop]>]
    @State private var width: CGFloat = 0.0
    @State private var removingStop: RemovingStop? = nil
    
    public init(stops: Binding<[Stop]>) {
        self.allStops = [stops]
    }
    
    public init<C: RandomAccessCollection & Sendable>(
        sources: C,
        stop: KeyPath<C.Element, Binding<[Stop]>> & Sendable
    ) {
        allStops = sources.map { $0[keyPath: stop] }
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
    func linearGradientView(for stops: Binding<[Stop]>) -> some View {
        LinearGradient(
            stops: stops.wrappedValue.sorted(by: { $0.offset < $1.offset }).map {
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
    func colorStop(for stop: Binding<Stop>, width: CGFloat) -> some View {
        ColorChip(
            color: Binding(
                get: {
                    stop.wrappedValue.color
                },
                set: {
                    stop.wrappedValue = Stop(id: stop.wrappedValue.id, offset: stop.wrappedValue.offset, color: $0)
                }
            )
        )
        .background(alignment: .top) {
            if let removingStop, removingStop.id == stop.wrappedValue.id {
                VStack {
                    ColorChip(
                        color: Binding.constant(BaseKit.Color.black)
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
                stops.wrappedValue = presentedStops[index].wrappedValue
            }
        }
    }
    
    static let defaultStops: [GradientView.Stop] = [
        GradientView.Stop(id: UUID(), offset: 0.0, color: .white),
        GradientView.Stop(id: UUID(), offset: 1.0, color: .black),
    ]
    
    var stops: Binding<[Stop]> {
        if let stop = allStops.only {
            return stop
        } else {
            return Binding<[Stop]>(
                get: {
                    allStops.first?.wrappedValue ?? GradientView.defaultStops
                },
                set: { newValue, transaction in
                    for stop in allStops {
                        stop.wrappedValue = newValue
                    }
                }
            )
        }
    }
    
    var hasSingleSetOfStops: Bool {
        uniqueStops.count == 1
    }
    
    var uniqueStops: [Binding<[Stop]>] {
        var unique = [Binding<[Stop]>]()
        for stop in allStops {
            let haveEquivalent = unique.contains { $0.isEquivalent(to: stop) }
            guard !haveEquivalent else {
                continue
            }
            unique.append(stop)
        }
        return unique
    }
    
    var presentedStops: [Binding<[Stop]>] {
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
        let stops = stops.wrappedValue.sorted(by: { $0.offset < $1.offset })
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
            self.stops.wrappedValue.insert(newStop, at: insertIndex)
        } else {
            // append and just re-use the last
            let newStop = GradientView.Stop(
                id: UUID(),
                offset: offset,
                color: stops.last?.color ?? .black
            )
            self.stops.wrappedValue.append(newStop)
        }
    }
    
    struct RemovingStop: Equatable {
        let id: UUID
        let location: CGPoint
    }
    
    func dragStop(_ stop: Binding<Stop>, to location: CGPoint, width: CGFloat) {
        guard isEditable(stop) else {
            return
        }
        
        if isRemoving(location: location, width: width) {
            self.removingStop = RemovingStop(
                id: stop.wrappedValue.id,
                location: location
            )
        } else {
            self.removingStop = nil
            stop.wrappedValue = Stop(
                id: stop.wrappedValue.id,
                offset: clamp(location.x / width, 0.0, 1.0),
                color: stop.wrappedValue.color
            )
        }
    }
    
    func dragStopFinished(_ stop: Binding<Stop>, to location: CGPoint, width: CGFloat) {
        guard isEditable(stop) else {
            return
        }

        if isRemoving(location: location, width: width) {
            self.stops.wrappedValue.removeAll(where: { $0.id == stop.wrappedValue.id })
        } else {
            stop.wrappedValue = Stop(
                id: stop.wrappedValue.id,
                offset: clamp(location.x / width, 0.0, 1.0),
                color: stop.wrappedValue.color
            )
        }
        self.removingStop = nil
    }
    
    func isRemoving(location: CGPoint, width: CGFloat) -> Bool {
        let chipSize = ColorChip.bodyHeight
        let halfChipSize = chipSize / 2.0
        return (location.x < -halfChipSize) || (location.x > (width + halfChipSize))
        || (location.y < -halfChipSize) || (location.y > (chipSize + halfChipSize))
    }
    
    func stopLocation(_ stop: Binding<Stop>, width: CGFloat) -> CGPoint {
        if let removingStop, removingStop.id == stop.wrappedValue.id {
            return removingStop.location
        } else {
            return CGPoint(
                x: stop.wrappedValue.offset * width,
                y: ColorChip.centerYOffset
            )
        }
    }
    
    func isEditable(_ stop: Binding<Stop>) -> Bool {
        // Need a minimum of two, first and last can't be moved from 0, 1
        let sorted = stops.wrappedValue.sorted(by: { $0.offset < $1.offset })
        let isFirst = sorted.first?.id == stop.wrappedValue.id
        let isLast = sorted.last?.id == stop.wrappedValue.id
        return !isFirst && !isLast
    }
}

private extension GradientView.Stop {
    func isEquivalent(to other: GradientView.Stop) -> Bool {
        offset == other.offset && color == other.color
    }
}

private extension Array where Element == GradientView.Stop {
    func isEquivalent(to other: [GradientView.Stop]) -> Bool {
        count == other.count && zip(self, other).allSatisfy { $0.isEquivalent(to: $1) }
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
        GradientView(stops: $stops)
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
        GradientView(sources: $stops, stop: \.self)
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
