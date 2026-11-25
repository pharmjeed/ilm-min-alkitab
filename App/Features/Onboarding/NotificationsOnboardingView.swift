import SwiftUI
import UserNotifications

/// First launch only (owner 2026-11-24): a quiet page with the brand mark and «علم من الكتاب», and over it a
/// pop-up asking to enable notifications. One button, no skip — the iPhone's own permission dialog lets the
/// person decline; either answer continues to «الرئيسية».
struct NotificationsOnboardingView: View {
    /// False while the opening shot is still playing over this page; the pop-up waits for it.
    var ready = true
    var onDone: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var showPopup = false

    var body: some View {
        let t = Theme(scheme)
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                BrandMark(color: t.gold).frame(width: 120, height: 120)
                // owner 2026-11-25: the name larger, in black (the cream of the dark mode) and bolder
                Text("علم من الكتاب").font(AppFont.serif(46)).foregroundStyle(t.cream).heavier(t.cream)
            }
            .offset(y: -20)

            if showPopup {
                Color.black.opacity(0.55).ignoresSafeArea().transition(.opacity)
                NotificationsPopup(onDone: onDone)
                    .padding(.horizontal, 16)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .task(id: ready) {
            guard ready, !showPopup else { return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { showPopup = true }
        }
    }
}

/// The pop-up card: title, one line, how the morning notification looks, and the button.
private struct NotificationsPopup: View {
    var onDone: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            Text("فعّل الإشعارات").font(AppFont.serif(28)).foregroundStyle(t.cream)
            Text("يصلك كل صباح اسمٌ من أسماء الله، ومعناه، ومتى تدعوه به.")
                .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.82))
                .multilineTextAlignment(.center).lineSpacing(5)
                .padding(.top, 8)
            NotificationPreview(title: "اسم اليوم: الحليم الغفور",
                                message: "السماءُ فوق رأسك لم تسقط بعد — ذلك حلمُه؛ وبابُ التوبة لم يُغلق بعد — تلك مغفرتُه.")
                .padding(.top, 18)
            Button {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    DispatchQueue.main.async { onDone() }
                }
            } label: {
                Text("فعّل الإشعارات").font(AppFont.sans(18, .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(t.gold, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Palette.night)
            }
            .padding(.top, 20)
            Text("إشعارٌ واحد في الصباح، ويمكنك تغيير وقته من «المزيد».")
                .font(AppFont.sans(13)).foregroundStyle(t.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
        .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 18)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(t.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    }
}

/// How the morning notification looks on the lock screen.
struct NotificationPreview: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(alignment: .leading, spacing: 6) {
            Text("هكذا يصلك").font(AppFont.sans(13)).foregroundStyle(t.muted).padding(.horizontal, 16)
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 9).fill(Palette.night)
                    .overlay(BrandMark(color: Palette.gold(.dark)).padding(6))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(t.gold.opacity(0.35)))
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("علم من الكتاب")
                        Spacer()
                        Text("الآن")
                    }
                    .font(AppFont.sans(13)).foregroundStyle(t.muted)
                    Text(title).font(AppFont.sans(15, .bold)).foregroundStyle(t.cream)
                    Text(message).font(AppFont.sans(15)).foregroundStyle(t.cream.opacity(0.9)).lineSpacing(3)
                }
            }
            .padding(14)
            .background(t.cream.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
        }
    }
}
