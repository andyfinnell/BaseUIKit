import SwiftUI

struct RemoveTag: View {
    var body: some View {
        Text("Remove")
            .font(.caption)
            .foregroundColor(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 0.5))
            )
    }
}

#Preview {
    RemoveTag()
        .padding()
}
