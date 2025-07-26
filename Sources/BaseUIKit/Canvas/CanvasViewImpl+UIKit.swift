#if canImport(UIKit)
import UIKit
import BaseKit
import Synchronization

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
        canvasView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        canvasView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        canvasView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        canvasView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        backgroundColor = Color.pasteboard.native
        delaysContentTouches = false
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
    
    public override var bounds: CGRect {
        didSet {
            canvasView.visibleSize = bounds.size
        }
    }
    
    public override var frame: CGRect {
        didSet {
            canvasView.visibleSize = frame.size
        }
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer || gestureRecognizer == pinchGestureRecognizer {
            return false
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
    
    func updateContentInsets() {
        var contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
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
        if self.contentInset != contentInsets {
            self.contentInset = contentInsets
        }
    }

    public override var contentOffset: CGPoint {
        didSet {
            canvasView.visibleOffset = contentOffset
        }
    }
}

public final class CanvasViewImpl<ID: Hashable & Sendable>: UIView {
    private let database: Mutex<CanvasDatabase<ID>>
    var onDimensionsChanged: ((CanvasViewDimensions) -> Void)?
    var onEvent: ((Event) -> Void)?
    private var primaryTouch: UITouch? = nil
    private var allTouches = Set<UITouch>()

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
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        isExclusiveTouch = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // This causes some methods and properties to be invoked on background threads.
    //  If we override said methods/properties then Swift's inserted asserts about
    //  being on the MainActor will fire and crash the app. Effectively, this means
    //  certain overrides are actually now nonisolated.
    public override class var layerClass: AnyClass {
        CATiledLayer.self
    }

    public override var intrinsicContentSize: CGSize {
        db.contentSize
    }
    
    public nonisolated override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let db = database.withLock { $0 }
        db.drawRect(rect, into: context)
    }
    
    public nonisolated override var frame: CGRect {
        didSet {
            let db = database.withLock { $0 }
            db.setBounds(CGRect(origin: .zero, size: frame.size))
        }
    }
        
    public nonisolated override var bounds: CGRect {
        didSet {
            let didChange = bounds != oldValue
            let newBounds = CGRect(origin: .zero, size: frame.size)
            let db = database.withLock { $0 }
            db.setBounds(newBounds)
            
            if didChange {
                Task { @MainActor in
                    frameDidUpdate()
                }
            }
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

extension CanvasViewImpl {
    func updateScrollPosition(_ position: CGPoint) {
        layoutIfNeeded()
        
        guard let scrollView = enclosingScrollView else {
            return
        }
        let availableRect = scrollView.bounds
        let contentSize = intrinsicContentSize
        var position = position

        if contentSize.width <= availableRect.width {
            position.x = 0
        } else if position.x < 0 {
            position.x = 0
        } else if position.x > (contentSize.width - availableRect.width) {
            position.x = contentSize.width - availableRect.width
        }
        if contentSize.height <= availableRect.height {
            position.y = 0
        } else if position.y < 0 {
            position.y = 0
        } else if position.y > (contentSize.height - availableRect.height) {
            position.y = contentSize.height - availableRect.height
        }

        scrollView.setContentOffset(position, animated: false)
    }
    
    func updateScrollPosition(centeredAt centeredPosition: CGPoint) {
        layoutIfNeeded()

        guard let scrollView = enclosingScrollView else {
            return
        }
        let availableRect = scrollView.bounds
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

        scrollView.setContentOffset(position, animated: false)
    }
    
    func updateContentInsets() {
        canvasScrollView?.updateContentInsets()
    }
    
    func updateViewScale(_ viewScale: CGFloat) {
        if viewScale == 1.0 {
            transform = .identity
        } else {
            transform = CGAffineTransformMakeScale(viewScale, viewScale)
        }
    }
}

private extension CanvasViewImpl {
    var enclosingScrollView: UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    var canvasScrollView: CanvasScrollViewImpl<ID>? {
        var current: UIView? = superview
        while let view = current {
            if let scrollView = view as? CanvasScrollViewImpl<ID> {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    func frameDidUpdate() {
        enclosingScrollView?.contentSize = bounds.size        
    }
    
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
                locationInWindowCoords: windowLocation(for: primaryTouch),
                keyboardModifiers: event.map { keyboardModifiers(for: $0) } ?? [],
                when: timestamp(for: primaryTouch),
                button: .left,
                touches: Set(allTouches.map { makeTouch(from: $0) }),
                canvas: eventCanvas()
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
        let locationCG = db.convertViewToDocument(locationInView)
        return Point(x: locationCG.x, y: locationCG.y)
    }
    
    func windowLocation(for touch: UITouch) -> Point {
        Point(touch.preciseLocation(in: nil))
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
