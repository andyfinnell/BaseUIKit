import Foundation
import SwiftUI
import BaseKit

struct DocumentFileURLKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

public extension EnvironmentValues {
    var documentFileURL: URL? {
        get {
            self[DocumentFileURLKey.self]
        }
        set {
            self[DocumentFileURLKey.self] = newValue
        }
    }
}

struct DocumentFileURLHashKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

public extension EnvironmentValues {
    var documentFileURLHash: String? {
        get {
            self[DocumentFileURLHashKey.self]
        }
        set {
            self[DocumentFileURLHashKey.self] = newValue
        }
    }
}

public extension View {
    func documentFileURL(_ url: URL?) -> some View {
        environment(\.documentFileURL, url)
            .environment(\.documentFileURLHash, url?.absoluteString.hashedString())
    }
}
