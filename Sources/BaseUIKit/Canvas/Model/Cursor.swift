public enum Cursor: Sendable, Hashable {
    case `default`
    case crosshair
    case zoomIn
    case zoomOut
    case openHand
    case closedHand
    case move
    case resizeNorth
    case resizeSouth
    case resizeEast
    case resizeWest
    case resizeNorthWest
    case resizeNorthEast
    case resizeSouthWest
    case resizeSouthEast
    case iBeam
    case penClosePath
    case penAddPoint
    case penRemovePoint
    case penContinue
    case penConvertPoint
}
