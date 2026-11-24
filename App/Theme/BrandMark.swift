import SwiftUI

/// The platform's brand mark «المربّعات المتدرّجة» — the same logo as the website
/// (platform `brand/logo-mark.svg`, viewBox 120): three squares turned 0°, 22.5° and 45°
/// with fading strokes, and a dot at the centre.
struct BrandMark: View {
    var color: Color
    /// Stroke width in the mark's 120-unit space (the site uses 2.5); never thinner than ~1 pt on screen.
    var lineWidth: CGFloat = 2.5
    var showDot = true

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 120
            let w = max(lineWidth * s, 0.9)
            ZStack {
                square(104 * s, 0, w, color)
                square(80 * s, 22.5, w, color.opacity(0.85))
                square(56 * s, 45, w, color.opacity(0.7))
                if showDot {
                    Circle().fill(color).frame(width: 9 * s, height: 9 * s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    private func square(_ side: CGFloat, _ degrees: Double, _ width: CGFloat, _ c: Color) -> some View {
        Rectangle()
            .stroke(c, style: StrokeStyle(lineWidth: width, lineJoin: .round))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(degrees))
    }
}
