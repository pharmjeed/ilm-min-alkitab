import SwiftUI
import UserNotifications

/// The only first-launch step (owner's journey): enable notifications. One button, no skip —
/// the iPhone's own permission dialog lets the person decline; either answer continues to «الرئيسية».
struct NotificationsOnboardingView: View {
    var onDone: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: 10) {
                BrandMark(color: t.gold).frame(width: 84, height: 84)
                Text("علم من الكتاب").font(AppFont.serif(22)).foregroundStyle(t.gold)
                Text("فعّل الإشعارات").font(AppFont.serif(30)).foregroundStyle(t.cream).padding(.top, 14)
                Text("يصلك كل صباح اسمٌ من أسماء الله، ومعناه، ومتى تدعوه به.")
                    .font(AppFont.sans(17)).foregroundStyle(t.cream.opacity(0.82))
                    .multilineTextAlignment(.center).lineSpacing(6)
            }
            .padding(.horizontal, 24)

            NotificationPreview(title: "اسم اليوم: الحليم الغفور",
                                message: "السماءُ فوق رأسك لم تسقط بعد — ذلك حلمُه؛ وبابُ التوبة لم يُغلق بعد — تلك مغفرتُه.")
                .padding(.horizontal, 16).padding(.top, 28)

            Spacer()
            VStack(spacing: 10) {
                Button {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        DispatchQueue.main.async { onDone() }
                    }
                } label: {
                    Text("فعّل الإشعارات").font(AppFont.sans(18, .bold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(t.gold, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Palette.night)
                }
                Text("إشعارٌ واحد في الصباح، ويمكنك تغيير وقته من «المزيد».")
                    .font(AppFont.sans(13)).foregroundStyle(t.muted)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.bg.ignoresSafeArea())
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
