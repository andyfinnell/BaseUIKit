import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import BaseKit

extension FilterLayer {
    /// Renders content into an offscreen buffer, applies the filter chain, and draws the result
    /// into the given context. If offscreen allocation fails, draws content directly instead.
    func drawFiltered(
        into context: CGContext,
        scale: CGFloat,
        renderingCache: RenderingCache?,
        drawContent: (CGContext) -> Void
    ) {
        let filterRegion = region.toCG
        let pixelWidth = Int(filterRegion.width * scale)
        let pixelHeight = Int(filterRegion.height * scale)
        guard pixelWidth > 0, pixelHeight > 0,
              let offscreen = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            drawContent(context)
            return
        }
        offscreen.scaleBy(x: scale, y: scale)
        offscreen.translateBy(x: -filterRegion.origin.x, y: -filterRegion.origin.y)
        drawContent(offscreen)

        if let sourceImage = offscreen.makeImage(),
           let filteredImage = applyFilter(to: sourceImage, scale: scale, renderingCache: renderingCache) {
            context.draw(filteredImage, in: filterRegion)
        } else if let sourceImage = offscreen.makeImage() {
            context.draw(sourceImage, in: filterRegion)
        }
    }
}

private extension FilterLayer {
    func applyFilter(to sourceImage: CGImage, scale: CGFloat, renderingCache: RenderingCache?) -> CGImage? {
        let ciContext = renderingCache?.ciContext ?? CIContext()
        let sourceGraphic = CIImage(cgImage: sourceImage)
        let sourceAlpha = extractAlpha(from: sourceGraphic)

        var namedResults: [String: CIImage] = [:]
        var lastResult = sourceGraphic

        for primitive in primitives {
            let input1 = resolveInput(primitive.input, sourceGraphic: sourceGraphic, sourceAlpha: sourceAlpha, named: namedResults, lastResult: lastResult)
            let input2 = primitive.input2.map { resolveInput($0, sourceGraphic: sourceGraphic, sourceAlpha: sourceAlpha, named: namedResults, lastResult: lastResult) }

            guard let result = applyEffect(primitive.effect, input: input1, input2: input2, sourceGraphic: sourceGraphic, sourceAlpha: sourceAlpha, named: namedResults, lastResult: lastResult) else {
                continue
            }

            lastResult = result
            if let name = primitive.result {
                namedResults[name] = result
            }
        }

        let extent = sourceGraphic.extent
        return ciContext.createCGImage(lastResult, from: extent)
    }

    func resolveInput(
        _ input: FilterInput,
        sourceGraphic: CIImage,
        sourceAlpha: CIImage,
        named: [String: CIImage],
        lastResult: CIImage
    ) -> CIImage {
        switch input {
        case .sourceGraphic:
            return sourceGraphic
        case .sourceAlpha:
            return sourceAlpha
        case let .named(name):
            return named[name] ?? lastResult
        }
    }

    func extractAlpha(from image: CIImage) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return filter.outputImage ?? image
    }

    func applyEffect(
        _ effect: FilterEffect,
        input: CIImage,
        input2: CIImage?,
        sourceGraphic: CIImage,
        sourceAlpha: CIImage,
        named: [String: CIImage],
        lastResult: CIImage
    ) -> CIImage? {
        switch effect {
        case let .gaussianBlur(stdDeviationX, stdDeviationY):
            return applyGaussianBlur(input: input, stdDeviationX: stdDeviationX, stdDeviationY: stdDeviationY)
        case let .offset(dx, dy):
            return applyOffset(input: input, dx: dx, dy: dy)
        case let .flood(color, opacity):
            return applyFlood(color: color, opacity: opacity, extent: input.extent)
        case let .blend(mode):
            return applyBlend(input: input, input2: input2 ?? sourceGraphic, mode: mode)
        case let .composite(op, k1, k2, k3, k4):
            return applyComposite(input: input, input2: input2 ?? sourceGraphic, operator: op, k1: k1, k2: k2, k3: k3, k4: k4)
        case let .merge(inputs):
            return applyMerge(inputs: inputs, sourceGraphic: sourceGraphic, sourceAlpha: sourceAlpha, named: named, lastResult: lastResult)
        case let .colorMatrix(type, values):
            return applyColorMatrix(input: input, type: type, values: values)
        case let .morphology(op, radiusX, radiusY):
            return applyMorphology(input: input, operator: op, radiusX: radiusX, radiusY: radiusY)
        case let .convolveMatrix(orderRows, orderCols, kernel, divisor, bias, _, _, _, _):
            return applyConvolveMatrix(input: input, orderRows: orderRows, orderCols: orderCols, kernel: kernel, divisor: divisor, bias: bias)
        case .tile:
            return applyTile(input: input, extent: input.extent)
        case let .displacementMap(scale, _, _):
            return applyDisplacementMap(input: input, input2: input2, scale: scale)
        case let .turbulence(type, _, _, _, _):
            return applyTurbulence(type: type, extent: input.extent)
        case let .filterImage(imageData):
            return applyFilterImage(imageData: imageData, extent: input.extent)
        case let .componentTransfer(funcR, funcG, funcB, funcA):
            return applyComponentTransfer(input: input, funcR: funcR, funcG: funcG, funcB: funcB, funcA: funcA)
        case let .diffuseLighting(surfaceScale, diffuseConstant, _):
            return applyDiffuseLighting(input: input, surfaceScale: surfaceScale, diffuseConstant: diffuseConstant)
        case let .specularLighting(surfaceScale, specularConstant, _, _):
            return applySpecularLighting(input: input, surfaceScale: surfaceScale, specularConstant: specularConstant)
        }
    }

    func applyGaussianBlur(input: CIImage, stdDeviationX: Double, stdDeviationY: Double) -> CIImage? {
        // CIGaussianBlur uses a single radius; average the two deviations
        let radius = (stdDeviationX + stdDeviationY) / 2.0
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input
        filter.radius = Float(radius)
        // Clamp to extent to avoid transparent edges from blur expansion
        return filter.outputImage?.cropped(to: input.extent)
    }

    func applyOffset(input: CIImage, dx: Double, dy: Double) -> CIImage? {
        let transform = CGAffineTransform(translationX: dx, y: -dy) // CG y-axis is flipped
        return input.transformed(by: transform)
    }

    func applyFlood(color: BaseKit.Color, opacity: Double, extent: CGRect) -> CIImage? {
        let ciColor = CIColor(
            red: color.red * opacity,
            green: color.green * opacity,
            blue: color.blue * opacity,
            alpha: opacity
        )
        return CIImage(color: ciColor).cropped(to: extent)
    }

    func applyBlend(input: CIImage, input2: CIImage, mode: FilterBlendMode) -> CIImage? {
        let filter: CIFilter & CICompositeOperation
        switch mode {
        case .normal:
            filter = CIFilter.sourceOverCompositing()
        case .multiply:
            filter = CIFilter.multiplyBlendMode()
        case .screen:
            filter = CIFilter.screenBlendMode()
        case .darken:
            filter = CIFilter.darkenBlendMode()
        case .lighten:
            filter = CIFilter.lightenBlendMode()
        }
        filter.inputImage = input
        filter.backgroundImage = input2
        return filter.outputImage
    }

    func applyComposite(
        input: CIImage,
        input2: CIImage,
        operator compositeOp: FilterCompositeOperator,
        k1: Double, k2: Double, k3: Double, k4: Double
    ) -> CIImage? {
        switch compositeOp {
        case .over:
            return compositeOver(input: input, background: input2)
        case .in:
            return compositeIn(input: input, background: input2)
        case .out:
            return compositeOut(input: input, background: input2)
        case .atop:
            return compositeAtop(input: input, background: input2)
        case .xor:
            return compositeXor(input: input, background: input2)
        case .arithmetic:
            return compositeArithmetic(input: input, background: input2, k1: k1, k2: k2, k3: k3, k4: k4)
        }
    }

    func compositeOver(input: CIImage, background: CIImage) -> CIImage? {
        let filter = CIFilter.sourceOverCompositing()
        filter.inputImage = input
        filter.backgroundImage = background
        return filter.outputImage
    }

    func compositeIn(input: CIImage, background: CIImage) -> CIImage? {
        let filter = CIFilter.sourceInCompositing()
        filter.inputImage = input
        filter.backgroundImage = background
        return filter.outputImage
    }

    func compositeOut(input: CIImage, background: CIImage) -> CIImage? {
        let filter = CIFilter.sourceOutCompositing()
        filter.inputImage = input
        filter.backgroundImage = background
        return filter.outputImage
    }

    func compositeAtop(input: CIImage, background: CIImage) -> CIImage? {
        let filter = CIFilter.sourceAtopCompositing()
        filter.inputImage = input
        filter.backgroundImage = background
        return filter.outputImage
    }

    func compositeXor(input: CIImage, background: CIImage) -> CIImage? {
        // No built-in XOR; approximate with (A out B) over (B out A)
        guard let aOutB = compositeOut(input: input, background: background),
              let bOutA = compositeOut(input: background, background: input) else {
            return nil
        }
        return compositeOver(input: aOutB, background: bOutA)
    }

    func compositeArithmetic(input: CIImage, background: CIImage, k1: Double, k2: Double, k3: Double, k4: Double) -> CIImage? {
        // result = k1*i1*i2 + k2*i1 + k3*i2 + k4
        // Simplified approach: scale input by k2, background by k3, add via compositing
        // For a proper arithmetic composite, we'd need a custom CIKernel.
        let scaledInput = applyColorMatrixScale(input: input, scale: k2)
        let scaledBg = applyColorMatrixScale(input: background, scale: k3)

        let filter = CIFilter.additionCompositing()
        filter.inputImage = scaledInput ?? input
        filter.backgroundImage = scaledBg ?? background
        return filter.outputImage
    }

    func applyColorMatrixScale(input: CIImage, scale: Double) -> CIImage? {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = input
        filter.rVector = CIVector(x: scale, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: scale, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: scale, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: scale)
        filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return filter.outputImage
    }

    func applyMerge(
        inputs: [FilterInput],
        sourceGraphic: CIImage,
        sourceAlpha: CIImage,
        named: [String: CIImage],
        lastResult: CIImage
    ) -> CIImage? {
        guard let first = inputs.first else { return nil }
        var result = resolveInput(first, sourceGraphic: sourceGraphic, sourceAlpha: sourceAlpha, named: named, lastResult: lastResult)

        for mergeInput in inputs.dropFirst() {
            let layer = resolveInput(mergeInput, sourceGraphic: sourceGraphic, sourceAlpha: sourceAlpha, named: named, lastResult: lastResult)
            guard let composited = compositeOver(input: layer, background: result) else {
                continue
            }
            result = composited
        }
        return result
    }

    func applyColorMatrix(input: CIImage, type: ColorMatrixType, values: [Double]) -> CIImage? {
        switch type {
        case .matrix:
            return applyFullColorMatrix(input: input, values: values)
        case .saturate:
            let s = values.first ?? 1.0
            return applySaturate(input: input, saturation: s)
        case .hueRotate:
            let angle = values.first ?? 0.0
            return applyHueRotate(input: input, angleDegrees: angle)
        case .luminanceToAlpha:
            return applyLuminanceToAlpha(input: input)
        }
    }

    func applyFullColorMatrix(input: CIImage, values: [Double]) -> CIImage? {
        guard values.count >= 20 else { return nil }
        let filter = CIFilter.colorMatrix()
        filter.inputImage = input
        // SVG matrix is 5x4 (rows are RGBA output, cols are RGBA input + bias)
        // CIColorMatrix uses column vectors for R,G,B,A plus bias
        filter.rVector = CIVector(x: values[0], y: values[1], z: values[2], w: values[3])
        filter.gVector = CIVector(x: values[5], y: values[6], z: values[7], w: values[8])
        filter.bVector = CIVector(x: values[10], y: values[11], z: values[12], w: values[13])
        filter.aVector = CIVector(x: values[15], y: values[16], z: values[17], w: values[18])
        filter.biasVector = CIVector(x: values[4], y: values[9], z: values[14], w: values[19])
        return filter.outputImage
    }

    func applySaturate(input: CIImage, saturation: Double) -> CIImage? {
        let filter = CIFilter.colorControls()
        filter.inputImage = input
        filter.saturation = Float(saturation)
        return filter.outputImage
    }

    func applyHueRotate(input: CIImage, angleDegrees: Double) -> CIImage? {
        let filter = CIFilter.hueAdjust()
        filter.inputImage = input
        filter.angle = Float(angleDegrees * .pi / 180.0)
        return filter.outputImage
    }

    func applyLuminanceToAlpha(input: CIImage) -> CIImage? {
        // R'=0, G'=0, B'=0, A' = 0.2126R + 0.7152G + 0.0722B
        let filter = CIFilter.colorMatrix()
        filter.inputImage = input
        filter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.aVector = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return filter.outputImage
    }

    // MARK: - Remaining Filter Primitives

    func applyMorphology(input: CIImage, operator op: MorphologyOperator, radiusX: Double, radiusY: Double) -> CIImage? {
        switch op {
        case .erode:
            let filter = CIFilter.morphologyMinimum()
            filter.inputImage = input
            filter.radius = Float(max(radiusX, radiusY))
            return filter.outputImage?.cropped(to: input.extent)
        case .dilate:
            let filter = CIFilter.morphologyMaximum()
            filter.inputImage = input
            filter.radius = Float(max(radiusX, radiusY))
            return filter.outputImage?.cropped(to: input.extent)
        }
    }

    func applyConvolveMatrix(input: CIImage, orderRows: Int, orderCols: Int, kernel: [Double], divisor: Double, bias: Double) -> CIImage? {
        // Normalize kernel by divisor and add bias
        let normalizedKernel = kernel.map { Float($0 / divisor) }
        let floatBias = Float(bias)

        // CIFilter supports 3x3, 5x5, 7x7 square convolutions
        let order = max(orderRows, orderCols)
        if order <= 3 {
            let padded = padKernel(normalizedKernel, to: 9)
            let filter = CIFilter.convolution3X3()
            filter.inputImage = input
            filter.weights = CIVector(values: padded.map { CGFloat($0) }, count: 9)
            filter.bias = floatBias
            return filter.outputImage?.cropped(to: input.extent)
        } else if order <= 5 {
            let padded = padKernel(normalizedKernel, to: 25)
            let filter = CIFilter.convolution5X5()
            filter.inputImage = input
            filter.weights = CIVector(values: padded.map { CGFloat($0) }, count: 25)
            filter.bias = floatBias
            return filter.outputImage?.cropped(to: input.extent)
        } else if order <= 7 {
            let padded = padKernel(normalizedKernel, to: 49)
            let filter = CIFilter.convolution7X7()
            filter.inputImage = input
            filter.weights = CIVector(values: padded.map { CGFloat($0) }, count: 49)
            filter.bias = floatBias
            return filter.outputImage?.cropped(to: input.extent)
        }
        // Unsupported sizes pass through
        return input
    }

    func padKernel(_ kernel: [Float], to count: Int) -> [Float] {
        if kernel.count >= count {
            return Array(kernel.prefix(count))
        }
        return kernel + Array(repeating: Float(0), count: count - kernel.count)
    }

    func applyTile(input: CIImage, extent: CGRect) -> CIImage? {
        let filter = CIFilter.affineTile()
        filter.inputImage = input
        filter.transform = CGAffineTransform.identity
        return filter.outputImage?.cropped(to: extent)
    }

    func applyDisplacementMap(input: CIImage, input2: CIImage?, scale: Double) -> CIImage? {
        guard let displacementImage = input2 else { return input }
        let filter = CIFilter.displacementDistortion()
        filter.inputImage = input
        filter.displacementImage = displacementImage
        filter.scale = Float(scale)
        return filter.outputImage?.cropped(to: input.extent)
    }

    func applyTurbulence(type: TurbulenceType, extent: CGRect) -> CIImage? {
        // Approximation using CIRandomGenerator + blur
        let filter = CIFilter.randomGenerator()
        guard var noise = filter.outputImage?.cropped(to: extent) else {
            return nil
        }
        if type == .fractalNoise {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = noise
            blur.radius = 2.0
            noise = blur.outputImage?.cropped(to: extent) ?? noise
        }
        return noise
    }

    func applyFilterImage(imageData: Data, extent: CGRect) -> CIImage? {
        guard let ciImage = CIImage(data: imageData) else { return nil }
        // Scale to fit extent
        let scaleX = extent.width / ciImage.extent.width
        let scaleY = extent.height / ciImage.extent.height
        return ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
            .cropped(to: extent)
    }

    func applyComponentTransfer(
        input: CIImage,
        funcR: TransferFunction,
        funcG: TransferFunction,
        funcB: TransferFunction,
        funcA: TransferFunction
    ) -> CIImage? {
        // For identity and linear types, use CIColorMatrix
        // Table/discrete/gamma are approximated
        let filter = CIFilter.colorMatrix()
        filter.inputImage = input

        let (rScale, rBias) = linearCoefficients(funcR)
        let (gScale, gBias) = linearCoefficients(funcG)
        let (bScale, bBias) = linearCoefficients(funcB)
        let (aScale, aBias) = linearCoefficients(funcA)

        filter.rVector = CIVector(x: rScale, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: gScale, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: bScale, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: aScale)
        filter.biasVector = CIVector(x: rBias, y: gBias, z: bBias, w: aBias)
        return filter.outputImage
    }

    func linearCoefficients(_ func_: TransferFunction) -> (CGFloat, CGFloat) {
        switch func_.type {
        case .identity:
            return (1.0, 0.0)
        case .linear:
            return (CGFloat(func_.slope), CGFloat(func_.intercept))
        case .gamma:
            // Approximate gamma as linear with amplitude as scale
            return (CGFloat(func_.amplitude), CGFloat(func_.offset))
        case .table, .discrete:
            // Approximation: use first two table values as linear
            if func_.tableValues.count >= 2 {
                let slope = func_.tableValues[1] - func_.tableValues[0]
                return (CGFloat(slope), CGFloat(func_.tableValues[0]))
            }
            return (1.0, 0.0)
        }
    }

    func applyDiffuseLighting(input: CIImage, surfaceScale: Double, diffuseConstant: Double) -> CIImage? {
        // Approximation: convert to heightfield and apply shading
        let heightField = CIFilter.heightFieldFromMask()
        heightField.inputImage = input
        heightField.radius = Float(surfaceScale * 2)
        guard let heightImage = heightField.outputImage else { return input }

        let material = CIFilter.shadedMaterial()
        material.inputImage = heightImage
        material.scale = Float(diffuseConstant)
        // Create a simple shading image
        material.shadingImage = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: input.extent)
        return material.outputImage?.cropped(to: input.extent)
    }

    func applySpecularLighting(input: CIImage, surfaceScale: Double, specularConstant: Double) -> CIImage? {
        // Same approach as diffuse with specular scaling
        let heightField = CIFilter.heightFieldFromMask()
        heightField.inputImage = input
        heightField.radius = Float(surfaceScale * 2)
        guard let heightImage = heightField.outputImage else { return input }

        let material = CIFilter.shadedMaterial()
        material.inputImage = heightImage
        material.scale = Float(specularConstant)
        material.shadingImage = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: input.extent)
        return material.outputImage?.cropped(to: input.extent)
    }
}
