import SwiftUI

/// «ربع الحزب» star (brand/logo): an axis-aligned square + a 45° square + an inner ring + a dot.
/// Geometry copied from assets/brand/mark.svg (viewBox 120).
struct BrandMark: View {
    var color: Color
    var lineWidth: CGFloat = 6
    var showRing = true

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 120
            ZStack {
                Path { p in
                    p.addLines([CGPoint(x: 95.36, y: 24.64), CGPoint(x: 95.36, y: 95.36), CGPoint(x: 24.64, y: 95.36), CGPoint(x: 24.64, y: 24.64)].map { $0.scaled(s) })
                    p.closeSubpath()
                    p.addLines([CGPoint(x: 110, y: 60), CGPoint(x: 60, y: 110), CGPoint(x: 10, y: 60), CGPoint(x: 60, y: 10)].map { $0.scaled(s) })
                    p.closeSubpath()
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth * s, lineJoin: .miter))
                if showRing {
                    Circle().stroke(color.opacity(0.85), lineWidth: 3.25 * s)
                        .frame(width: 32 * s, height: 32 * s)
                    Circle().fill(color).frame(width: 10 * s, height: 10 * s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

private extension CGPoint {
    func scaled(_ s: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
}
