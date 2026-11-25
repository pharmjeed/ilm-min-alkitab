import SwiftUI
import UIKit

/// The opening shot on every launch (owner 2026-11-24, option «رسم الشعار»): the three squares of the brand mark
/// draw themselves one after another, the centre dot pops, then «علم من الكتاب» rises in. About two seconds;
/// a tap skips it. Same geometry as the first-launch page (`NotificationsOnboardingView`), so on the very first
/// launch it ends exactly on that page and the notifications pop-up follows.
struct SplashView: View {
    /// CI screenshot of the finished shot: never calls `onFinish`.
    var hold = false
    var onFinish: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var p1: CGFloat = 0
    @State private var p2: CGFloat = 0
    @State private var p3: CGFloat = 0
    @State private var dot: CGFloat = 0
    @State private var nameIn = false
    @State private var finished = false

    var body: some View {
        let t = Theme(scheme)
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    square(104, 0, p1, t.gold)
                    square(80, 22.5, p2, t.gold.opacity(0.85))
                    square(56, 45, p3, t.gold.opacity(0.7))
                    Circle().fill(t.gold).frame(width: 9, height: 9).scaleEffect(dot)
                }
                .frame(width: 120, height: 120)
                // owner 2026-11-25: the name larger and in black (the cream of the dark mode)
                Text("علم من الكتاب").font(AppFont.serif(46)).foregroundStyle(t.cream)
                    .opacity(nameIn ? 1 : 0)
                    .offset(y: nameIn ? 0 : 10)
            }
            .offset(y: -20)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("علم من الكتاب")
        .task { await run() }
    }

    private func square(_ side: CGFloat, _ degrees: Double, _ progress: CGFloat, _ color: Color) -> some View {
        Rectangle()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(degrees))
    }

    private func run() async {
        if UIAccessibility.isReduceMotionEnabled {
            p1 = 1; p2 = 1; p3 = 1; dot = 1; nameIn = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            finish()
            return
        }
        withAnimation(.easeOut(duration: 0.55)) { p1 = 1 }
        withAnimation(.easeOut(duration: 0.55).delay(0.35)) { p2 = 1 }
        withAnimation(.easeOut(duration: 0.55).delay(0.7)) { p3 = 1 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(1.1)) { dot = 1 }
        withAnimation(.easeOut(duration: 0.6).delay(1.25)) { nameIn = true }
        try? await Task.sleep(nanoseconds: 2_300_000_000)
        finish()
    }

    private func finish() {
        guard !finished, !hold else { return }
        finished = true
        onFinish()
    }
}
