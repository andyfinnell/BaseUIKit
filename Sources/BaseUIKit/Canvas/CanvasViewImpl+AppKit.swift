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
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        
        super.init(frame: .zero)
        
        documentView = canvasView
        
        automaticallyAdjustsContentInsets = false
        backgroundColor = Color.pasteboard.native
                
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: self
        )
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
    
    func updateContentInsets() {
        var contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let contentSize = canvasView.intrinsicContentSize
        let availableSize = bounds.size
        if contentSize.width < availableSize.width {
            let x = round((availableSize.width - contentSize.width) / 2.0)
            contentInsets.left = x
            contentInsets.right = x
        }
        if contentSize.height < availableSize.height {
            let y = round((availableSize.height - contentSize.height) / 2.0)
            contentInsets.top = y
            contentInsets.bottom = y
        }
        if self.contentInsets != contentInsets {
            self.contentInsets = contentInsets
        }
    }
    
    @objc
    private func onScroll(_ notification: Notification) {
        canvasView.visibleOffset = documentVisibleRect.origin
    }
}

extension NSEdgeInsets: @retroactive Equatable {
    public static func == (lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        lhs.top == rhs.top
        && lhs.bottom == rhs.bottom
        && lhs.left == rhs.left
        && lhs.right == rhs.right
    }
}

public final class CanvasViewImpl<ID: Hashable & Sendable>: NSView {
    private let database: Mutex<CanvasDatabase<ID>>
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    var onEvent: ((Event) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isCursorInside = false
    
    var db: CanvasDatabase<ID> {
        get { database.withLock { $0 } }
        set { database.withLock { $0 = newValue } }
    }
    
    var visibleSize: CGSize {
        get { db.visibleSize }
        set { db.setVisibleSize(newValue) }
    }
    
    var visibleOffset: CGPoint {
        get { db.visibleOffset }
        set { db.visibleOffset = newValue }
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
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.initialFirstResponder = self
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
    
    public override func scroll(_ point: NSPoint) {
        super.scroll(point)
        visibleOffset = point
    }

}

private extension CanvasViewImpl {
    var canvasScrollView: CanvasScrollViewImpl<ID>? {
        enclosingScrollView as? CanvasScrollViewImpl<ID>
    }
    
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
                .mouseCancelled,
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
                locationInWindowCoords: Point(event.locationInWindow),
                keyboardModifiers: keyboardModifiers(for: event),
                when: timestamp(for: event),
                button: button,
                touches: Set(),
                canvas: eventCanvas()
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
                rawKeyCode: event.keyCode,
                canvas: eventCanvas()
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
                rawKeyCode: event.keyCode,
                canvas: eventCanvas()
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
                isInside: isInsideView,
                canvas: eventCanvas()
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
}

extension CanvasViewImpl {
    func resetCursor() {
        guard isCursorInside else {
            return
        }
        setCursor()
    }
    
    func updateScrollPosition(_ position: CGPoint) {
        layoutSubtreeIfNeeded()
        scroll(position)
    }

    func updateScrollPosition(centeredAt centeredPosition: CGPoint) {
        layoutSubtreeIfNeeded()
        
        guard let availableRect = enclosingScrollView?.bounds else {
            return
        }
        let contentSize = intrinsicContentSize
        var position = CGPoint(
            x: centeredPosition.x - (availableRect.width / 2),
            y: centeredPosition.y - (availableRect.height / 2)
        )

        if contentSize.width <= availableRect.width {
            position.x = 0
        }
        if contentSize.height <= availableRect.height {
            position.y = 0
        }

        scroll(position)
    }

    func updateContentInsets() {
        canvasScrollView?.updateContentInsets()
    }
}

#endif
