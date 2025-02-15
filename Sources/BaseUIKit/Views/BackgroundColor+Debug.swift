import SwiftUI

public extension View {
    func randomBackgroundColor() -> some View {
        background(Color.random())
    }
}

struct PreviewRandomBackground: View {
    @State private var count = 0
    
    var body: some View {
        HStack {
            Viewer(count: count)
            
            Editor(count: $count)
            
            Unchanged()
            
            Spacer()
        }
    }
    
    struct Unchanged: View {
        var body: some View {
            Text("No changes")
                .randomBackgroundColor()
        }
    }
    
    struct Viewer: View {
        let count: Int
        
        var body: some View {
            Text("Count: \(count)")
                .randomBackgroundColor()
        }
    }
    
    struct Editor: View {
        @Binding var count: Int
        
        var body: some View {
            Button("Increment") { count += 1 }
                .randomBackgroundColor()
        }
    }
}

#Preview {
    VStack {
        PreviewRandomBackground()
            .padding()
        
        Spacer()
    }
}
