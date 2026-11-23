import SwiftUI

/// «محفوظاتي». Saving needs the (optional) account — owner's rule: nothing is saved on the device alone —
/// so until the account exists this tab explains how saving works.
struct SavedView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "bookmark").font(.system(size: 40)).foregroundStyle(t.gold).padding(.top, 36)
                Text("محفوظاتك في حسابك").font(AppFont.serif(26)).foregroundStyle(t.cream)
                Text("الحفظ يحتاج إلى تسجيل الدخول: ما تحفظه يُحفظ في حسابك، فتجده هنا على أي جهازٍ تدخل منه.")
                    .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.85))
                    .multilineTextAlignment(.center).lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    step(t, "heart", "اضغط «مفضلة» على أي آية أو حديث، أو على أي سنّة.")
                    step(t, "person.crop.circle", "سجّل الدخول بـ«آبل» أو «قوقل».")
                    step(t, "bookmark", "تجد ما حفظته هنا في «محفوظاتي».")
                }
                .siteCard(t, padding: 18)
                .padding(.top, 8)
                Text("الحساب اختياري، والتطبيق كله متاحٌ دونه. (تسجيل الدخول قريبًا)")
                    .font(AppFont.sans(13)).foregroundStyle(t.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("محفوظاتي")
    }

    private func step(_ t: Theme, _ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon).foregroundStyle(t.gold).frame(width: 22)
            Text(text).font(AppFont.sans(15)).foregroundStyle(t.cream)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
