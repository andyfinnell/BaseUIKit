import SwiftUI
import WebKit

public struct WebContent: Equatable {
    public let data: Data
    public let mimeType: String
    public let characterEncodingName: String
    public let baseURL: URL
    
    public init(data: Data, mimeType: String, characterEncodingName: String, baseURL: URL) {
        self.data = data
        self.mimeType = mimeType
        self.characterEncodingName = characterEncodingName
        self.baseURL = baseURL
    }
    
    public init(svg: String, baseURL: URL = URL(string: "https://losingfight.com")!) {
        data = Data(svg.utf8)
        mimeType = "image/svg+xml"
        self.characterEncodingName = "utf-8"
        self.baseURL = baseURL
    }
}

#if canImport(AppKit)
import AppKit

public struct WebView: NSViewRepresentable {
    private let content: WebContent
    
    public init(content: WebContent) {
        self.content = content
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(
            content.data,
            mimeType: content.mimeType,
            characterEncodingName: content.characterEncodingName,
            baseURL: content.baseURL
        )
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        webView.load(
            content.data,
            mimeType: content.mimeType,
            characterEncodingName: content.characterEncodingName,
            baseURL: content.baseURL
        )
    }
}

#endif


#if canImport(UIKit)
import UIKit

public struct WebView: UIViewRepresentable {
    private let content: WebContent
    
    public init(content: WebContent) {
        self.content = content
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(
            content.data,
            mimeType: content.mimeType,
            characterEncodingName: content.characterEncodingName,
            baseURL: content.baseURL
        )
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(
            content.data,
            mimeType: content.mimeType,
            characterEncodingName: content.characterEncodingName,
            baseURL: content.baseURL
        )
    }
}

#endif
