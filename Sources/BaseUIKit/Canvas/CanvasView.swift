import Foundation
import SwiftUI
import BaseKit

public struct CanvasViewDimensions: Hashable, Sendable {
    public let size: Size
    public let screenDPI: Double
    
    public init(size: Size, screenDPI: Double) {
        self.size = size
        self.screenDPI = screenDPI
    }
}

#if canImport(AppKit)
import AppKit

public struct CanvasView<ID: Hashable & Sendable>: NSViewRepresentable {
    private let database: CanvasDatabase<ID>
    private let onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    private let onEvent: ((Event) -> Void)?
    
    public init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)? = nil,
        onEvent: ((Event) -> Void)? = nil
    ) {
        self.database = database
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
    }
    
    public func makeNSView(context: Context) -> CanvasViewRepresentable<ID> {
        CanvasViewRepresentable(
            database: database,
            onDimensionsChanged: onDimensionsChanged,
            onEvent: onEvent
        )
    }
    
    public func updateNSView(_ nsView: CanvasViewRepresentable<ID>, context: Context) {
        nsView.database = database
        nsView.onDimensionsChanged = onDimensionsChanged
        nsView.onEvent = onEvent
    }
}

public final class CanvasViewRepresentable<ID: Hashable & Sendable>: NSView {
    var database: CanvasDatabase<ID>
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    var onEvent: ((Event) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isCursorInside = false
    
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
        
        let trackingArea = makeTrackingArea()
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: NSSize {
        database.contentSize
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        database.drawRect(dirtyRect, into: context)
    }
    
    func setNeedsDisplay() {
        setNeedsDisplay(bounds)
    }
    
    public override var frame: CGRect {
        didSet {
            database.bounds = CGRect(origin: .zero, size: frame.size)
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

private extension CanvasViewRepresentable {
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
        let locationCG = database.convertViewToDocument(locationInView)
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
        database.cursor.set()
    }
        
    func resetCursor() {
        guard isCursorInside else {
            return
        }
        setCursor()
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

#endif

#if canImport(UIKit)
import UIKit

public struct CanvasView<ID: Hashable & Sendable>: UIViewRepresentable {
    private let database: CanvasDatabase<ID>
    private let onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    private let onEvent: ((Event) -> Void)?
    
    public init(
        database: CanvasDatabase<ID>,
        onDimensionsChanged: ((CanvasViewDimensions) -> Void)? = nil,
        onEvent: ((Event) -> Void)? = nil
    ) {
        self.database = database
        self.onDimensionsChanged = onDimensionsChanged
        self.onEvent = onEvent
    }
    
    public func makeUIView(context: Context) -> CanvasViewRepresentable<ID> {
        CanvasViewRepresentable(
            database: database,
            onDimensionsChanged: onDimensionsChanged,
            onEvent: onEvent
        )
    }
    
    public func updateUIView(_ nsView: CanvasViewRepresentable<ID>, context: Context) {
        nsView.database = database
        nsView.onDimensionsChanged = onDimensionsChanged
        nsView.onEvent = onEvent
    }
}

public final class CanvasViewRepresentable<ID: Hashable & Sendable>: UIView {
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
        database.viewContentSize
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

private extension CanvasViewRepresentable {
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


extension CanvasViewRepresentable: CanvasCoreViewDelegate {
    func invalidateCanvas() {
        setNeedsDisplay()
    }
    
    func invalidateRect(_ rect: CGRect) {
        setNeedsDisplay(rect)
    }
    
    func invalidateContentSize() {
        invalidateIntrinsicContentSize()
        notifyDimensionsChanged()
    }
    
    func invalidateCursor() {
        #if canImport(AppKit)
        resetCursor()
        #endif
    }
}

private extension CanvasViewRepresentable {
    func notifyDimensionsChanged() {
        guard let onDimensionsChanged else {
            return
        }
        let dimensions = CanvasViewDimensions(
            size: Size(width: database.width, height: database.height),
            screenDPI: database.screenDPI
        )
        onDimensionsChanged(dimensions)
    }
    
    func sendEvent(_ event: Event) {
        onEvent?(event)
    }
}
