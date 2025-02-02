
public enum Event: Hashable, Sendable {
    case pointer(PointerEvent)
    case key(KeyEvent)
    case cursor(CursorEvent)
}
