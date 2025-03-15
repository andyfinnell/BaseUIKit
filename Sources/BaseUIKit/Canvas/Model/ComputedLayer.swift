import BaseKit

public struct LayerFactoryID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct LayerFactoryContext: Hashable, Sendable {
    public let structurePath: BezierPath
    
    public init(structurePath: BezierPath) {
        self.structurePath = structurePath
    }
}

public struct LayerFactory<ID: Hashable & Sendable>: Hashable, Sendable {
    public let id: LayerFactoryID
    private let compute: @Sendable (Layer<ID>, LayerFactoryContext) -> [Layer<ID>]
    
    public init(id: LayerFactoryID, compute: @escaping @Sendable (Layer<ID>, LayerFactoryContext) -> [Layer<ID>]) {
        self.id = id
        self.compute = compute
    }
    
    public func callAsFunction(_ layer: Layer<ID>, withContext context: LayerFactoryContext) -> [Layer<ID>] {
        compute(layer, context)
    }
    
    public static func ==(lhs: LayerFactory<ID>, rhs: LayerFactory<ID>) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

public struct ComputedLayer<ID: Hashable & Sendable>: Hashable, Sendable, Identifiable {
    public let id: ID
    public let basedOn: ID
    public let factory: LayerFactory<ID>
    
    public init(id: ID, basedOn: ID, factory: LayerFactory<ID>) {
        self.id = id
        self.basedOn = basedOn
        self.factory = factory
    }
}
