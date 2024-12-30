import SwiftUI
import BaseKit

struct MulticolorView: View {
    let colors: [BaseKit.Color]
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if colors.isEmpty {
            Color.clear
                .frame(width: width, height: height)
        } else {
            HStack(spacing: 0) {
                ForEach(limitedColors, id: \.self) { color in
                    ColorStripe(color: color, width: stripeWidth, height: rotatedWidth)
                }
            }
            .rotationEffect(.degrees(45))
            .frame(width: width, height: height)
            .clipped()
        }
    }
}

private extension MulticolorView {
    var rotatedWidth: CGFloat {
        sqrt(width * width + height * height)
    }
    
    var stripeWidth: CGFloat {
        let stripeCount = limitedColors.count
        return rotatedWidth / CGFloat(stripeCount)
    }
    
    var limitedColors: [BaseKit.Color] {
        var limited = [BaseKit.Color]()
        let maxCount = maximumColors
        for color in colors where limited.count <= maxCount {
            guard !limited.contains(color) else {
                continue
            }
            limited.append(color)
        }
        return limited
    }
    
    var maximumColors: Int {
        Int(floor(rotatedWidth / ColorStripe.minimumWidth))
    }
}

private struct ColorStripe: View {
    let color: BaseKit.Color
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        color.swiftUI
            .frame(width: width, height: height)
    }
    
    static let minimumWidth: CGFloat = 4.0
}

#Preview {
    MulticolorView(colors: [
        .blue,
        .red,
        .yellow,
        .purple,
        .orange,
    ], width: 44, height: 44)
}
