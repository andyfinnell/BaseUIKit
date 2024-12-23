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
    
    private var stops: Binding<[Stop]>
    @State private var width: CGFloat = 0.0
    @State private var removingStop: RemovingStop? = nil
    
    public init(stops: Binding<[Stop]>) {
        self.stops = stops
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: stops.wrappedValue.sorted(by: { $0.offset < $1.offset }).map {
                    Gradient.Stop(color: $0.color.swiftUI, location: $0.offset)
                },
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 44)
            .onTapGesture { location in
                insertStop(at: location, inWidth: width)
            }

            Color.secondary
                .frame(height: ColorChip.bodyHeight)
                .onTapGesture { location in
                    insertStop(at: location, inWidth: width)
                }
                .overlay {
                    GeometryReader { geometry in
                        ForEach(stops) { stop in
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
                            .position(stopLocation(stop, width: geometry.size.width))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragStop(stop, to: value.location, width: geometry.size.width)
                                    }
                                    .onEnded { value in
                                        dragStopFinished(stop, to: value.location, width: geometry.size.width)
                                    }
                            )
                        }
                        .onChange(of: geometry.size.width, initial: true) { _, new in
                            self.width = new
                        }
                    }
                }
        }
    }
}

private extension GradientView {
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

#Preview {
    GradientViewPreview()
        .padding()
}
