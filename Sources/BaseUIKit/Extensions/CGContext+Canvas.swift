import CoreGraphics

public extension CGContext {
    func drawCheckboard(_ rect: CGRect) {
        // TODO: on macOS at least, this doesn't work well when scrolling
        guard let pattern = CGPattern.makeCheckerboard(),
            let patternColorspace = CGColorSpace(patternBaseSpace: nil) else {
            return
        }
        
        saveGState()
        defer {
            restoreGState()
        }
        
        var components: [CGFloat] = [1.0, 1.0, 1.0, 1.0]
        setFillColorSpace(patternColorspace)
        setPatternPhase(
            CGSize(
                width: rect.minX.truncatingRemainder(dividingBy: 20),
                height: rect.minY.truncatingRemainder(dividingBy: 20)
            )
        )
        setFillPattern(pattern, colorComponents: &components)
        fill(rect)
    }
}

extension CGPattern {
    static func makeCheckerboard() -> CGPattern? {
        let patternSize = 20.0
        
        func drawPattern(info: UnsafeMutableRawPointer?, context: CGContext) {
            let squareSize = 10.0
            
            context.setFillColor(gray: 2.0 / 3.0, alpha: 1.0)
            context.fill(CGRect(x: 0, y: 0, width: squareSize, height: squareSize))
            context.fill(CGRect(x: squareSize, y: squareSize, width: squareSize, height: squareSize))

            context.setFillColor(gray: 1.0, alpha: 1.0)
            context.fill(CGRect(x: 0, y: squareSize, width: squareSize, height: squareSize))
            context.fill(CGRect(x: squareSize, y: 0, width: squareSize, height: squareSize))
        }
        
        var callbacks = CGPatternCallbacks(
            version: 0,
            drawPattern: drawPattern,
            releaseInfo: nil
        )
        return CGPattern(
            info: nil,
            bounds: CGRect(
                x: 0,
                y: 0,
                width: patternSize,
                height: patternSize
            ),
            matrix: .identity,
            xStep: patternSize,
            yStep: patternSize,
            tiling: .noDistortion,
            isColored: true,
            callbacks: &callbacks
        )
    }
}
