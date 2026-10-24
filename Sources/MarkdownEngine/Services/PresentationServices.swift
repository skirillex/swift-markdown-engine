//
//  PresentationServices.swift
//  MarkdownEngine
//
//  Presentation-only services: folded heading sections and code blocks drawn as
//  images. Neither changes the source text. Both report a fingerprint; when it
//  changes the editor restyles, the way it does for embedded images.
//

import AppKit
import Foundation

/// Which heading sections are folded. A folded section — everything after the
/// heading up to the next heading of the same or a higher level — collapses to
/// nothing; the heading itself stays visible.
public protocol MarkdownFoldingProvider: Sendable {
    /// `heading` is the heading's text without the `#` marker, trimmed.
    func isFolded(heading: String, level: Int) -> Bool
    /// Changes whenever the folded set changes.
    func fingerprint() -> AnyHashable
}

public struct NoFolding: MarkdownFoldingProvider {
    public init() {}
    public func isFolded(heading: String, level: Int) -> Bool { false }
    public func fingerprint() -> AnyHashable { 0 }
}

/// A rendered code block.
public struct CodeBlockImage {
    public let image: NSImage
    public init(image: NSImage) { self.image = image }
}

/// Renders a fenced code block of a given language as an image (a diagram, a
/// chart). Return nil to leave the block as code — for unknown languages, or
/// while an asynchronous render is still running (then change the fingerprint
/// when it finishes, and the block is restyled). The caret inside the block
/// shows the source as usual.
public protocol CodeBlockImageRenderer: Sendable {
    func image(language: String, code: String, maxWidth: CGFloat) -> CodeBlockImage?
    func fingerprint() -> AnyHashable
}

public struct NoCodeBlockImages: CodeBlockImageRenderer {
    public init() {}
    public func image(language: String, code: String, maxWidth: CGFloat) -> CodeBlockImage? { nil }
    public func fingerprint() -> AnyHashable { 0 }
}
