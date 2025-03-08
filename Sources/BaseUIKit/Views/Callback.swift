
@MainActor
struct Call<Parameter, Return>: Equatable {
    let callback: (Parameter) -> Return
    
    init(_ callback: @escaping (Parameter) -> Return) {
        self.callback = callback
    }
    
    func callAsFunction(_ parameter: Parameter) -> Return {
        callback(parameter)
    }
    
    nonisolated static func ==(lhs: Call<Parameter, Return>, rhs: Call<Parameter, Return>) -> Bool {
        true // always true
    }
}

extension Call where Parameter == Void {
    func callAsFunction() -> Return {
        callback(())
    }
}

typealias Callback<Parameter> = Call<Parameter, Void>
