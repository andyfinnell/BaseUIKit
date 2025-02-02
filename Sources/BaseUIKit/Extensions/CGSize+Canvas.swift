import Foundation

public func *(lhs: CGSize, rhs: Double) -> CGSize {
    .init(width: lhs.width * rhs, height: lhs.height * rhs)
}

public func /(lhs: CGSize, rhs: Double) -> CGSize {
    .init(width: lhs.width / rhs, height: lhs.height / rhs)
}

public func -(lhs: CGSize, rhs: CGSize) -> CGSize {
    .init(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
}
