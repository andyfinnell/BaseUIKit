import SwiftUI

@MainActor
final class Debouncer<Action: Equatable & Sendable> {
    private var lastAction: Action?
    private var realSend: ((Action) -> Void)?
    private var timer: Timer?
    
    init() {
    }
    
    func send(_ action: Action, realSend: @escaping (Action) -> Void) {
        lastAction = action
        self.realSend = realSend
        schedule()
    }
    
    func flush() {
        fire()
    }
}

private extension Debouncer {
    func schedule() {
        guard timer == nil else {
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fire()
            }
        }
    }
    
    func fire() {
        // Prevent multiple calls
        timer?.invalidate()
        timer = nil
        
        if let lastAction, let realSend {
            realSend(lastAction)
        }
        lastAction = nil
    }
}
