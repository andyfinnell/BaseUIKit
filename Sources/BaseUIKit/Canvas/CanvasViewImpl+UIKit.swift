#if canImport(UIKit)
import UIKit
import BaseKit

public final class CanvasScrollViewImpl<ID: Hashable & Sendable>: UIScrollView {
    let canvasView: CanvasViewImpl<ID>
    
    init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)?,
        onEvent: ((Event) -> Void)?
    ) {
        canvasView = CanvasViewImpl(
            database: database,
            onDimensionsChanged: onDimensionsChanged,
            onEvent: onEvent
        )
        super.init(frame: .zero)
        
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(canvasView)
        canvasView.widthAnchor.constraint(greaterThanOrEqualTo: widthAnchor, multiplier: 1.0).isActive = true
        canvasView.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, multiplier: 1.0).isActive = true
        canvasView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        canvasView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var database: CanvasDatabase<ID> {
        get { canvasView.database }
        set { canvasView.database = newValue }
    }
    
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)? {
        get { canvasView.onDimensionsChanged }
        set { canvasView.onDimensionsChanged = newValue }
    }
    
    var onEvent: ((Event) -> Void)? {
        get { canvasView.onEvent }
        set { canvasView.onEvent = newValue }
    }
}

public final class CanvasViewImpl<ID: Hashable & Sendable>: UIView {
    var database: CanvasDatabase<ID>
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    var onEvent: ((Event) -> Void)?
    private var primaryTouch: UITouch? = nil
    private var allTouches = Set<UITouch>()
    
    init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)?,
        onEvent: ((Event) -> Void)?
    ) {
        self.database = database
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
        super.init(frame: .zero)
        database.delegate = self
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        isExclusiveTouch = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: CGSize {
        database.contentSize
    }
    
    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        database.drawRect(rect, into: context)
    }
    
    public override var frame: CGRect {
        didSet {
            database.bounds = CGRect(origin: .zero, size: frame.size)
        }
    }
        
    public override var bounds: CGRect {
        didSet {
            let newBounds = CGRect(origin: .zero, size: frame.size)
            database.bounds = newBounds
        }
    }
    
    public override var canBecomeFirstResponder: Bool { true }
    
    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        
        return true
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let state = allTouches.isEmpty ? PointerEvent.State.down : .multitouchChange
        allTouches.formUnion(touches)
        updatePrimaryTouch()
        
        if let e = makeTouchEvent(from: touches, with: event, withState: state) {
            sendEvent(e)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        if let e = makeTouchEvent(from: touches, with: event, withState: .drag) {
            sendEvent(e)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let primaryTouch else {
            return
        }
        let newAllTouches = allTouches.subtracting(touches)
        let isPrimaryTouchEnded = !newAllTouches.contains(primaryTouch)
        let state = isPrimaryTouchEnded ? PointerEvent.State.up : .multitouchChange
        
        if let e = makeTouchEvent(from: touches, with: event, withState: state) {
            sendEvent(e)
        }
        
        if isPrimaryTouchEnded {
            allTouches.removeAll()
            self.primaryTouch = nil
        } else {
            allTouches = newAllTouches
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        guard let primaryTouch else {
            return
        }
        let newAllTouches = allTouches.subtracting(touches)
        let isPrimaryTouchCancelled = !newAllTouches.contains(primaryTouch)
        let state = isPrimaryTouchCancelled ? PointerEvent.State.cancel : .multitouchChange

        if let e = makeTouchEvent(from: touches, with: event, withState: state) {
            sendEvent(e)
        }
        
        if isPrimaryTouchCancelled {
            allTouches.removeAll()
            self.primaryTouch = nil
        } else {
            allTouches = newAllTouches
        }
    }
}

private extension CanvasViewImpl {
    func makeTouchEvent(
        from touches: Set<UITouch>,
        with event: UIEvent?,
        withState state: PointerEvent.State
    ) -> Event? {
        guard let primaryTouch else {
            return nil
        }
        return Event.pointer(
            PointerEvent(
                state: state,
                location: documentLocation(for: primaryTouch),
                keyboardModifiers: event.map { keyboardModifiers(for: $0) } ?? [],
                when: timestamp(for: primaryTouch),
                button: .left,
                touches: Set(allTouches.map { makeTouch(from: $0) })
            )
        )
    }
    
    func updatePrimaryTouch() {
        if let primaryTouch, allTouches.contains(primaryTouch) {
            // We have a primary touch and it's still valid
            return
        } else {
            primaryTouch = allTouches.sorted { areTouchesSorted($0, $1) }.first
        }
    }
    
    func areTouchesSorted(_ one: UITouch, _ two: UITouch) -> Bool {
        let location1 = one.location(in: self)
        let location2 = two.location(in: self)
        
        if location1.y != location2.y {
            return location1.y < location2.y
        } else {
            return location1.x < location2.x
        }
    }
    
    func makeTouch(from touch: UITouch) -> Touch {
        Touch(
            id: TouchID(touch),
            phase: phase(for: touch),
            location: documentLocation(for: touch),
            when: timestamp(for: touch),
            tapCount: touch.tapCount
        )
    }
    
    func phase(for touch: UITouch) -> Touch.Phase {
        switch touch.phase {
        case .began: .began
        case .moved: .moved
        case .stationary: .stationary
        case .ended: .ended
        case .cancelled: .cancelled
        case .regionEntered: .regionEntered
        case .regionMoved: .regionMoved
        case .regionExited: .regionExited
        @unknown default: .unknown
        }
    }
    
    func documentLocation(for touch: UITouch) -> Point {
        let locationInView = touch.preciseLocation(in: self)
        let locationCG = database.convertViewToDocument(locationInView)
        return Point(x: locationCG.x, y: locationCG.y)
    }
    
    func keyboardModifiers(for event: UIEvent) -> KeyboardModifiers {
        var modifiers: KeyboardModifiers = []
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.alternate) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.alphaShift) {
            modifiers.insert(.capsLock)
        }
        return modifiers
    }
        
    func timestamp(for touch: UITouch) -> Date {
        // NSEvent confusingly measures time since system start up to event time.
        // ProcessInfo.systemUptime is the time from system start up to now
        Date(timeIntervalSinceNow: -(ProcessInfo.processInfo.systemUptime - touch.timestamp))
    }
}

#endif
