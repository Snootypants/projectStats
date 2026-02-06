import SwiftUI

struct SparkleEdgeEffect: View {
    @State private var phase: Double = 0

    private let particleCount = 40
    private let baseColor = Color.accentColor

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawEdgeParticles(context: context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func drawEdgeParticles(context: GraphicsContext, size: CGSize, time: Double) {
        let perimeter = 2 * (size.width + size.height)

        for i in 0..<particleCount {
            let offset = Double(i) / Double(particleCount)
            let position = fmod(offset + time * 0.08, 1.0) // Travel speed
            let distance = position * perimeter

            let point = pointOnPerimeter(distance: distance, size: size)

            // Vary size and opacity per particle
            let seed = Double(i) * 1.618
            let pulse = (sin(time * 2.5 + seed) + 1) / 2.0
            let radius = 2.0 + pulse * 3.0
            let opacity = 0.3 + pulse * 0.5

            // Draw glow
            let glowRect = CGRect(
                x: point.x - radius * 2,
                y: point.y - radius * 2,
                width: radius * 4,
                height: radius * 4
            )
            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(baseColor.opacity(opacity * 0.3))
            )

            // Draw core
            let coreRect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: coreRect),
                with: .color(baseColor.opacity(opacity))
            )
        }
    }

    private func pointOnPerimeter(distance: Double, size: CGSize) -> CGPoint {
        let w = size.width
        let h = size.height
        var d = distance

        // Top edge
        if d < w { return CGPoint(x: d, y: 0) }
        d -= w
        // Right edge
        if d < h { return CGPoint(x: w, y: d) }
        d -= h
        // Bottom edge
        if d < w { return CGPoint(x: w - d, y: h) }
        d -= w
        // Left edge
        return CGPoint(x: 0, y: h - d)
    }
}
