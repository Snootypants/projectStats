import SwiftUI

struct MinimapView: View {
    let text: String
    let visibleRange: CGFloat
    let scrollOffset: CGFloat
    let onScroll: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Tiny text rendering
                Text(text)
                    .font(.system(size: 2))
                    .foregroundColor(.secondary.opacity(0.5))
                    .lineSpacing(0)
                    .frame(width: geo.size.width - 4, alignment: .leading)
                    .padding(2)

                // Visible area indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(height: max(geo.size.height * visibleRange, 20))
                    .offset(y: geo.size.height * scrollOffset * (1 - visibleRange))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = value.location.y / geo.size.height
                        onScroll(min(max(ratio, 0), 1))
                    }
            )
        }
        .frame(width: 60)
        .background(Color.primary.opacity(0.03))
    }
}
