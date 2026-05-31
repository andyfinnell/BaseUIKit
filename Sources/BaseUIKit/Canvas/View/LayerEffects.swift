import CoreGraphics
import BaseKit

/// The per-layer effects that wrap a draw-content call: opacity / blend
/// mode for transparency-layer compositing, a coordinate-space transform,
/// a clip-path, a mask, and a filter chain. Shared by `CanvasPath`,
/// `CanvasText`, and `CanvasGroup` so the wrapping logic stays in one
/// place and behaves identically across layer kinds.
struct LayerEffects {
    var opacity: Double
    var blendMode: BlendMode
    /// Concatenated into the context before `drawContent` runs. `.identity`
    /// for layers (like groups) whose children are already in canvas-global
    /// coords.
    var transform: Transform
    var clipPath: ClipPath?
    var mask: MaskLayer?
    /// Pre-rendered mask image. The caller is responsible for caching it
    /// across draw calls.
    var maskImage: CGImage?
    var filter: FilterLayer?

    /// Apply these effects to `context`, then run `drawContent`. Saves
    /// and restores the graphics state, opens a transparency layer when
    /// opacity / blend mode / mask / filter require offscreen
    /// composition, applies the transform, sets the clip-path, applies
    /// the mask, and routes content through the filter chain.
    ///
    /// The save / restore boundary is unconditional — even when no
    /// effects need to be applied — because layer renderers (e.g.
    /// `CanvasPath.locked_drawSelf`) mutate paint state without their
    /// own save/restore and rely on this wrapper to isolate that state
    /// from sibling layers. The fast path just skips the transparency
    /// layer / concatenate / clip / mask / filter steps.
    func draw(
        in context: CGContext,
        atScale scale: CGFloat,
        renderingCache: RenderingCache?,
        drawContent: (CGContext) -> Void
    ) {
        context.saveGState()
        defer { context.restoreGState() }

        let needsTransparencyLayer =
            opacity < 1.0
            || blendMode != .normal
            || mask != nil
            || filter != nil
        if needsTransparencyLayer {
            context.setAlpha(opacity)
            context.setBlendMode(blendMode.toCG)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }

        if transform != .identity {
            context.concatenate(transform.toCG)
        }

        if let clipPath {
            clipPath.path.set(in: context)
            context.clip(using: clipPath.fillRule.toCG)
        }

        if let mask, let maskImage {
            context.clip(to: mask.bounds.toCG, mask: maskImage)
        }

        if let filter {
            filter.drawFiltered(into: context, scale: scale, renderingCache: renderingCache) { target in
                drawContent(target)
            }
        } else {
            drawContent(context)
        }

        if needsTransparencyLayer {
            context.endTransparencyLayer()
        }
    }
}
