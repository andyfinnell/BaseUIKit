#if canImport(AppKit)
import AppKit
import BaseKit
import Synchronization

public final class CanvasScrollViewImpl<ID: Hashable & Sendable>: NSScrollView {
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
        
        self.documentView = canvasView
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvasView)
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
        get { canvasView.db }
        set { canvasView.db = newValue }
    }
    
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)? {
        get { canvasView.onDimensionsChanged }
        set { canvasView.onDimensionsChanged = newValue }
    }
    
    var onEvent: ((Event) -> Void)? {
        get { canvasView.onEvent }
        set { canvasView.onEvent = newValue }
    }
    
    public override var frame: CGRect {
        didSet {
            canvasView.visibleSize = frame.size
        }
    }
}

public final class CanvasViewImpl<ID: Hashable & Sendable>: NSView {
    private let database: Mutex<CanvasDatabase<ID>>
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    var onEvent: ((Event) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isCursorInside = false
    private var onBoundsChanged = [() -> Void]()
    
    var db: CanvasDatabase<ID> {
        get { database.withLock { $0 } }
        set { database.withLock { $0 = newValue } }
    }
    
    var visibleSize: CGSize {
        get { db.visibleSize }
        set { db.setVisibleSize(newValue) }
    }
    
    init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)?,
        onEvent: ((Event) -> Void)?
    ) {
        self.database = Mutex(database)
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
        super.init(frame: .zero)
        database.setDelegate(self)
        
        let trackingArea = makeTrackingArea()
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        
        canDrawConcurrently = true
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: NSSize {
        database.withLock {
            $0.contentSize
        }
    }
    
    public nonisolated override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        let db = database.withLock { $0 }
        db.drawRect(dirtyRect, into: context)
    }
    
    func setNeedsDisplay() {
        setNeedsDisplay(bounds)
    }
    
    public nonisolated override var frame: CGRect {
        didSet {
            let newBounds = CGRect(origin: .zero, size: frame.size)
            let db = database.withLock { $0 }
            db.setBounds(newBounds)
            
            Task { @MainActor in
                frameDidUpdate()
            }
        }
    }
    
    public override var isFlipped: Bool {
        true
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        
        return true
    }
    
    public override func mouseDown(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func rightMouseDragged(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }

    public override func otherMouseDown(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func otherMouseUp(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func otherMouseDragged(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func keyDown(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func keyUp(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func flagsChanged(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
        }
    }
    
    public override func cursorUpdate(with event: NSEvent) {
        if let e = makeEvent(from: event) {
            sendEvent(e)
            handleEvent(e)
        }
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove the old
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // Add the new
        let trackingArea = makeTrackingArea()
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
}

private extension CanvasViewImpl {
    func makeEvent(from event: NSEvent) -> Event? {
        switch event.type {
        case .leftMouseDown:
            return makeMouseEvent(from: event, withState: .down, button: .left)
        case .leftMouseUp:
            return makeMouseEvent(from: event, withState: .up, button: .left)
        case .leftMouseDragged:
            return makeMouseEvent(from: event, withState: .drag, button: .left)
        case .rightMouseDown:
            return makeMouseEvent(from: event, withState: .down, button: .right)
        case .rightMouseUp:
            return makeMouseEvent(from: event, withState: .up, button: .right)
        case .rightMouseDragged:
            return makeMouseEvent(from: event, withState: .drag, button: .right)
        case .otherMouseDown:
            return makeMouseEvent(from: event, withState: .down, button: .other)
        case .otherMouseUp:
            return makeMouseEvent(from: event, withState: .up, button: .other)
        case .otherMouseDragged:
            return makeMouseEvent(from: event, withState: .drag, button: .other)
        case .mouseMoved:
            return makeMouseEvent(from: event, withState: .move, button: .left)

        case .keyDown:
            return makeKeyEvent(from: event, withState: .down)
        case .keyUp:
            return makeKeyEvent(from: event, withState: .up)
        case .flagsChanged:
            return makeFlagsChangedEvent(from: event, withState: .modifiers)

        case .cursorUpdate:
            return makeCursorUpdateEvent(from: event)
            
        case .mouseEntered,
                .mouseExited,
                .appKitDefined,
                .systemDefined,
                .applicationDefined,
                .periodic,
                .scrollWheel,
                .tabletPoint,
                .tabletProximity,
                .gesture,
                .magnify,
                .swipe,
                .rotate,
                .beginGesture,
                .endGesture,
                .smartMagnify,
                .quickLook,
                .pressure,
                .directTouch,
                .changeMode:
            return nil
        @unknown default:
            return nil
        }
    }
    
    func makeMouseEvent(
        from event: NSEvent,
        withState state: PointerEvent.State,
        button: PointerEvent.Button
    ) -> Event? {
        Event.pointer(
            PointerEvent(
                state: state,
                location: documentLocation(for: event),
                keyboardModifiers: keyboardModifiers(for: event),
                when: timestamp(for: event),
                button: button,
                touches: Set()
            )
        )
    }
    
    func documentLocation(for event: NSEvent) -> Point {
        let locationInView = self.convert(event.locationInWindow, from: nil)
        let locationCG = db.convertViewToDocument(locationInView)
        return Point(x: locationCG.x, y: locationCG.y)
    }
    
    func keyboardModifiers(for event: NSEvent) -> KeyboardModifiers {
        var modifiers: KeyboardModifiers = []
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.capsLock) {
            modifiers.insert(.capsLock)
        }
        if event.modifierFlags.contains(.function) {
            modifiers.insert(.function)
        }
        return modifiers
    }
        
    func timestamp(for event: NSEvent) -> Date {
        // NSEvent confusingly measures time since system start up to event time.
        // ProcessInfo.systemUptime is the time from system start up to now
        Date(timeIntervalSinceNow: -(ProcessInfo.processInfo.systemUptime - event.timestamp))
    }
    
    func makeKeyEvent(
        from event: NSEvent,
        withState state: KeyEvent.State
    ) -> Event? {
        Event.key(
            KeyEvent(
                state: state,
                keyboardModifiers: keyboardModifiers(for: event),
                when: timestamp(for: event),
                characters: event.characters ?? "",
                charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
                isRepeat: event.isARepeat,
                rawKeyCode: event.keyCode
            )
        )
    }
    
    func makeFlagsChangedEvent(
        from event: NSEvent,
        withState state: KeyEvent.State
    ) -> Event? {
        Event.key(
            KeyEvent(
                state: state,
                keyboardModifiers: keyboardModifiers(for: event),
                when: timestamp(for: event),
                characters: "",
                charactersIgnoringModifiers: "",
                isRepeat: false,
                rawKeyCode: event.keyCode
            )
        )
    }

    func makeCursorUpdateEvent(from event: NSEvent) -> Event? {
        let locationInView = self.convert(event.locationInWindow, from: nil)
        let isInsideView = bounds.contains(locationInView)
        return Event.cursor(
            CursorEvent(
                location: documentLocation(for: event),
                when: timestamp(for: event),
                isInside: isInsideView
            )
        )
    }
    
    func handleEvent(_ event: Event) {
        switch event {
        case .key, .pointer:
            break // no special handling
        case let .cursor(cursorEvent):
            handleCursorEvent(cursorEvent)
        }
    }
    
    func handleCursorEvent(_ event: CursorEvent) {
        self.isCursorInside = event.isInside
        if event.isInside {
            setCursor()
        }
    }
    
    func setCursor() {
        db.cursor.set()
    }
            
    func makeTrackingArea() -> NSTrackingArea {
        NSTrackingArea(
            rect: self.bounds,
            options: [.cursorUpdate, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
    }
    
    func frameDidUpdate() {
        let blocks = onBoundsChanged
        onBoundsChanged.removeAll()
        for block in blocks {
            block()
        }
    }
    
    func queueScrollPositionUpdate(_ position: CGPoint) {
        let update = { [weak self] () -> Void in
            self?.scroll(position)
        }
        onBoundsChanged.append(update)
    }
}

extension CanvasViewImpl {
    func resetCursor() {
        guard isCursorInside else {
            return
        }
        setCursor()
    }
    
    func updateScrollPosition(_ position: CGPoint, needsToQueue: Bool) {
        if needsToQueue {
            // We can't handle this immediately because the view isn't resized yet,
            //  but we know it's about to be. So if we try to scroll right now,
            //  the coordinates will be wrong. So schedule a block to fire after
            //  the bounds change.
            queueScrollPositionUpdate(position)
        } else {
            scroll(position)
        }
    }
}

#endif
