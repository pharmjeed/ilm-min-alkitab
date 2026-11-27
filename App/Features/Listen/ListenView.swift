import SwiftUI

/// «الاستماع» (owner 2026-11-27): what plays, its controls, where to start, and the recitations kept on the phone.
struct ListenView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var player = ListenPlayer.shared
    @ObservedObject private var download = RecitationDownload.shared
    @State private var stored = (count: 0, megabytes: 0)

    var body: some View {
        let t = Theme(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                nowCard(t)
                if player.active { controls(t) }
                starts(t)
                downloads(t)
                Text("الآيات بصوت الشيخ مشاري العفاسي، وبقية الكلام بصوت الجوال. ولصوتٍ أوضح: «الإعدادات»، ثم «تسهيلات الاستخدام»، ثم «المحتوى المنطوق»، ثم «الأصوات»، ثم «العربية»، ونزّل صوتًا «محسّنًا».")
                    .font(AppFont.sans(13)).foregroundStyle(t.muted).lineSpacing(5)
            }
            .padding(20)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("الاستماع")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { stored = Recitations.stored() }
        .onChange(of: download.running) { _, _ in stored = Recitations.stored() }
    }

    private func nowCard(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tr = player.track, let c = player.cursor {
                Text(c.section == .names ? "الأسماء الحسنى" : "السنن").font(AppFont.sans(13, .medium)).foregroundStyle(t.gold)
                Text(tr.title).font(AppFont.serif(26)).foregroundStyle(t.cream).lineSpacing(6)
                Text(tr.subtitle).font(AppFont.sans(15)).foregroundStyle(t.muted)
                Text("\(c.track + 1) من \(player.trackCount)").font(AppFont.sans(13)).foregroundStyle(t.muted)
                if player.waiting {
                    Text("يُحمَّل صوت الآية…").font(AppFont.sans(13)).foregroundStyle(t.gold)
                }
                if let n = player.notice {
                    Text(n).font(AppFont.sans(13)).foregroundStyle(t.muted)
                }
            } else {
                Text("يقرأ لك المشغّل كل موضع من مواضع الأسماء كاملًا، وكل سنّة كاملة، ثم ينتقل إلى ما بعدها حتى يمر على المنصة كلها. ويبقى يعمل والجوال مقفل، وتتحكم فيه من شاشة القفل.")
                    .font(AppFont.sans(15)).foregroundStyle(t.cream).lineSpacing(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func controls(_ t: Theme) -> some View {
        let names = player.cursor?.section == .names
        return VStack(spacing: 14) {
            HStack(spacing: 34) {
                round(t, "backward.end.fill", 22) { player.previous() }
                round(t, player.playing ? "pause.fill" : "play.fill", 30, big: true) { player.toggle() }
                round(t, "forward.end.fill", 22) { player.next() }
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Button { Task { await player.previousUnit() } } label: {
                    Text(names ? "الاسم السابق" : "القسم السابق").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryPill())
                Button { Task { await player.nextUnit() } } label: {
                    Text(names ? "الاسم التالي" : "القسم التالي").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryPill())
            }
            Button { player.stop() } label: {
                Text("أوقف الاستماع").font(AppFont.sans(14)).foregroundStyle(t.muted)
            }
            .buttonStyle(.plain)
        }
    }

    private func round(_ t: Theme, _ icon: String, _ size: CGFloat, big: Bool = false,
                       _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size))
                .foregroundStyle(big ? t.bg : t.gold)
                .frame(width: big ? 72 : 52, height: big ? 72 : 52)
                .background(big ? t.gold : t.gold.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func starts(_ t: Theme) -> some View {
        VStack(spacing: 10) {
            if !player.active, let c = ListenPlayer.saved {
                Button { Task { await player.start(c) } } label: {
                    Label { Text("تابع من حيث توقفت: \(ListenPlan.unitTitle(c.section, c.unit))") }
                        icon: { Image(systemName: "play.fill") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryPill())
            }
            Button { Task { await player.start(ListenCursor(section: .names, unit: 0, track: 0)) } } label: {
                Text("ابدأ الأسماء الحسنى من أولها").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryPill())
            Button { Task { await player.start(ListenCursor(section: .sunan, unit: 0, track: 0)) } } label: {
                Text("ابدأ السنن من أولها").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryPill())
            Text("وتستمع لاسم أو سنّة بعينها بزر «استمع» في صفحتها.")
                .font(AppFont.sans(13)).foregroundStyle(t.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func downloads(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("التلاوات على جوالك").font(AppFont.sans(16, .bold)).foregroundStyle(t.gold)
            Text("محفوظ الآن: \(stored.count) آية (\(stored.megabytes) ميغابايت). ما تستمع إليه يُحفظ تلقائيًا ويعمل بعدها بلا إنترنت.")
                .font(AppFont.sans(14)).foregroundStyle(t.cream).lineSpacing(5)
            if download.running {
                ProgressView(value: Double(download.done), total: Double(max(download.total, 1))).tint(t.gold)
                HStack {
                    Text("يُنزَّل \(download.done) من \(download.total)").font(AppFont.sans(13)).foregroundStyle(t.muted)
                    Spacer()
                    Button("إيقاف") { download.cancel() }.font(AppFont.sans(14)).foregroundStyle(t.gold)
                }
            } else {
                Button { download.start() } label: {
                    Label { Text("نزّل كل التلاوات الآن") } icon: { Image(systemName: "arrow.down.circle") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryPill())
                Text(download.failed > 0
                     ? "لم تُنزَّل \(download.failed) آية لانقطاع الإنترنت؛ اضغط مرة أخرى لإكمالها."
                     : "قرابة 4200 آية، نحو 280 ميغابايت. يُفضَّل على شبكة «واي فاي»، ويُكمل من حيث توقف.")
                    .font(AppFont.sans(13)).foregroundStyle(t.muted).lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// While something plays: a bar above the tabs with what plays, pause / play, the next track, and close.
struct ListenMiniBar: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var player = ListenPlayer.shared
    @State private var open = false

    var body: some View {
        let t = Theme(scheme)
        if player.active, let tr = player.track {
            HStack(spacing: 14) {
                Button { open = true } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr.title).font(AppFont.sans(15, .bold)).foregroundStyle(WidgetLook.cream).lineLimit(1)
                        Text(tr.subtitle).font(AppFont.sans(12)).foregroundStyle(WidgetLook.gold).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button { player.toggle() } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.system(size: 20))
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.end.fill").font(.system(size: 18))
                }
                Button { player.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 15))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(WidgetLook.gold)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(WidgetLook.night, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(t.gold.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 66)
            .sheet(isPresented: $open) {
                NavigationStack { ListenView() }
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }
}

/// «استمع» on a name's or a sunnah's page.
struct ListenPill: View {
    let start: () async -> Void
    var body: some View {
        Button { Task { await start() } } label: {
            ActionPill { Label { Text("استمع") } icon: { Image(systemName: "headphones") } }
        }
        .buttonStyle(.plain)
    }
}
