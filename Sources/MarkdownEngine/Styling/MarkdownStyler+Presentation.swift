//
//  MarkdownStyler+Presentation.swift
//  MarkdownEngine
//
//  Presentation passes that sit on top of the regular styling: fenced code
//  blocks drawn as images (`services.codeBlockImages`), folded heading sections
//  (`services.folding`), and the collapse used by both folding and hidden
//  completed tasks. The source text is never changed; the caret reveals it.
//

import AppKit
import Foundation

extension NSAttributedString.Key {
    /// Full-width rounded box behind a block (value: `NSColor`). Set it from a
    /// block extension's `contentAttributes` for callouts; consecutive lines join
    /// into one box with rounded ends.
    public static let markdownBlockBox = NSAttributedString.Key("MarkdownBlockBox")
}

extension MarkdownStyler {
    /// Attributes that collapse a range to nothing: no glyph height, no colour,
    /// and every drawn decoration (images, boxes, checkboxes, bullets, rules)
    /// switched off, since those are painted from attributes rather than glyphs.
    static func collapsedAttributes() -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = 0.01
        para.maximumLineHeight = 0.01
        para.lineSpacing = 0
        para.paragraphSpacing = 0
        para.paragraphSpacingBefore = 0
        return [
            .font: NSFont.systemFont(ofSize: 0.01),
            .foregroundColor: NSColor.clear,
            .paragraphStyle: para,
            .backgroundColor: NSColor.clear,
            .markdownBlockBackground: NSColor.clear,
            .markdownBlockBox: NSNull(),
            .latexImage: NSNull(),
            .taskCheckbox: NSNull(),
            .thematicBreak: false,
            .bulletMarker: NSNull(),
            .bulletLevel: NSNull(),
            .orderedMarker: NSNull(),
            .blockquoteLevel: 0,
            .strikethroughStyle: 0,
        ]
    }

    // MARK: Folding

    /// Collapses the body of every folded heading section, unless the caret is in it.
    static func styleFoldedSections(_ ctx: StylingContext, caret: Int) -> [StyledRange] {
        let folding = ctx.services.folding
        let headings = ctx.tokens.filter { $0.kind == .heading }
        guard !headings.isEmpty else { return [] }
        let text = ctx.nsText
        func level(_ token: MarkdownToken) -> Int {
            var n = 0
            while token.range.location + n < text.length, text.character(at: token.range.location + n) == 0x23 { n += 1 }
            return max(1, n)
        }
        var out: [StyledRange] = []
        for (i, heading) in headings.enumerated() {
            let lvl = level(heading)
            let title = text.substring(with: heading.contentRange).trimmingCharacters(in: .whitespaces)
            guard folding.isFolded(heading: title, level: lvl) else { continue }
            let bodyStart = NSMaxRange(text.lineRange(for: NSRange(location: heading.range.location, length: 0)))
            var bodyEnd = text.length
            for next in headings[(i + 1)...] where level(next) <= lvl {
                bodyEnd = next.range.location
                break
            }
            guard bodyEnd > bodyStart else { continue }
            let body = NSRange(location: bodyStart, length: bodyEnd - bodyStart)
            if NSLocationInRange(caret, body) { continue }
            out.append((body, collapsedAttributes()))
        }
        return out
    }

    // MARK: Code blocks as images

    /// Replaces fenced code blocks the renderer understands with its image,
    /// centred and fitted to the column; the caret inside shows the source.
    static func styleCodeBlockImages(_ ctx: StylingContext) -> [StyledRange] {
        let renderer = ctx.services.codeBlockImages
        var attrs: [StyledRange] = []
        let maxWidth = effectiveContainerWidth(for: ctx)
        for (idx, token) in ctx.scoped(StylingContext.indexed(ctx.tokens, .codeBlock)) {
            guard !ctx.activeTokenIndices.contains(idx) else { continue }
            let full = ctx.nsText.substring(with: token.range)
            let firstLine = full.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
            let language = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "`~ \t")).lowercased()
            guard !language.isEmpty else { continue }
            let code = ctx.nsText.substring(with: token.contentRange)
            guard let rendered = renderer.image(language: language, code: code, maxWidth: maxWidth) else { continue }
            var size = rendered.image.size
            if size.width > maxWidth, size.width > 0 {
                size = CGSize(width: maxWidth, height: size.height * maxWidth / size.width)
            }
            let ok = appendRenderedStandaloneBlock(
                for: token,
                rawContent: code,
                image: rendered.image,
                imageBounds: CGRect(origin: .zero, size: size),
                paragraphSpacingBefore: 6,
                paragraphSpacing: 10,
                alignment: .center,
                mode: .collapsedSource(markerTexts: [firstLine, "```"]),
                ctx: ctx,
                attrs: &attrs
            )
            // The code block's own fill would otherwise paint behind the image.
            if ok { attrs.append((token.range, [.backgroundColor: NSColor.clear])) }
        }
        return attrs
    }
}
