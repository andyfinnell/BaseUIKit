import BaseKit

public enum Layer<ID: Hashable & Sendable>: Sendable, Hashable, Identifiable {
    case image(ImageLayer<ID>)
    case path(PathLayer<ID>)
    case text(TextLayer<ID>)
    case computed(ComputedLayer<ID>)
    
    public var id: ID {
        switch self {
        case let .image(i): i.id
        case let .path(p): p.id
        case let .text(t): t.id
        case let .computed(c): c.id
        }
    }
}
