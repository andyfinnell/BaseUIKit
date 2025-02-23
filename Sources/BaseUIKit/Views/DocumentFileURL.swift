import Foundation
import SwiftUI
import BaseKit

public extension EnvironmentValues {
    @Entry var documentFileURL: URL? = nil
    @Entry var documentFileURLHash: String? = nil
}

public extension View {
    func documentFileURL(_ url: URL?) -> some View {
        environment(\.documentFileURL, url)
            .environment(\.documentFileURLHash, url?.absoluteString.hashedString())
    }
}
