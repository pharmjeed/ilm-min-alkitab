import SwiftUI

/// «محفوظاتي». Saving needs the (optional) account — owner's rule: nothing is saved on the device alone.
/// Signed out: how saving works and a sign-in button. Signed in: the saved Quran positions and sunan.
struct SavedView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var signingIn = false

    var body: some View {
        let t = Theme(scheme)
        let account = Account.shared
        let store = SavedStore.shared
        ScrollView {
            Group {
                if account.isSignedIn {
                    signedIn(t, store)
                } else {
                    signedOut(t)
                }
            }
            .padding(20)
        }
        .refreshable { await store.reload() }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("محفوظاتي")
        .task {
            if account.isSignedIn && store.phase == .idle { await store.reload() }
        }
        .sheet(isPresented: $signingIn) { SaveSignInSheet(item: nil) }
    }

    // MARK: signed out

    private func signedOut(_ t: Theme) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark").font(.system(size: 40)).foregroundStyle(t.gold).padding(.top, 16)
            Text("محفوظاتك في حسابك").font(AppFont.serif(26)).foregroundStyle(t.cream)
            Text("الحفظ يحتاج إلى تسجيل الدخول: ما تحفظه يُحفظ في حسابك، فتجده هنا على أي جهازٍ تدخل منه.")
                .font(AppFont.sans(16)).foregroundStyle(t.cream.opacity(0.85))
                .multilineTextAlignment(.center).lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                step(t, "heart", "اضغط «احفظ» على أي آية أو على أي سنّة.")
                step(t, "person.crop.circle", "سجّل الدخول بـ«آبل» أو «قوقل».")
                step(t, "bookmark", "تجد ما حفظته هنا في «محفوظاتي».")
            }
            .siteCard(t, padding: 18)
            .padding(.top, 8)
            Button { signingIn = true } label: {
                Text("سجّل الدخول").font(AppFont.sans(17, .bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(t.gold, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Palette.night)
            }
            .padding(.top, 6)
            Text("الحساب اختياري، والتطبيق كله متاحٌ دونه.")
                .font(AppFont.sans(13)).foregroundStyle(t.muted)
                .multilineTextAlignment(.center)
        }
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

    // MARK: signed in

    @ViewBuilder
    private func signedIn(_ t: Theme, _ store: SavedStore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.isEmpty {
                switch store.phase {
                case .loading, .idle:
                    ProgressView().tint(t.gold).frame(maxWidth: .infinity).padding(.top, 40)
                case .failed:
                    VStack(spacing: 12) {
                        Text("تعذّر تحميل محفوظاتك.").font(AppFont.sans(16)).foregroundStyle(t.muted)
                        Button("حاول مرة أخرى") { Task { await store.reload() } }
                            .font(AppFont.sans(16, .medium)).foregroundStyle(t.gold)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                case .ready:
                    VStack(spacing: 12) {
                        Image(systemName: "heart").font(.system(size: 36)).foregroundStyle(t.gold)
                        Text("لم تحفظ شيئًا بعد").font(AppFont.serif(24)).foregroundStyle(t.cream)
                        Text("اضغط «احفظ» على أي آية أو على أي سنّة، فتجدها هنا.")
                            .font(AppFont.sans(15)).foregroundStyle(t.muted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                }
            }

            if !store.positions.isEmpty {
                sectionTitle(t, "من القرآن", store.positions.count)
                LazyVStack(spacing: 8) {
                    ForEach(store.positions, id: \.self) { key in
                        if let p = Self.parse(key) { positionRow(t, p) }
                    }
                }
            }

            if !store.sunan.isEmpty {
                sectionTitle(t, "من السنن", store.sunan.count).padding(.top, store.positions.isEmpty ? 0 : 12)
                LazyVStack(spacing: 8) {
                    ForEach(store.sunan, id: \.self) { fp in SavedSunnahRow(fp: fp) }
                }
            }
        }
    }

    private func sectionTitle(_ t: Theme, _ title: String, _ n: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AppFont.serif(24)).foregroundStyle(t.cream)
            Spacer()
            Text(Num.fmt(n)).font(AppFont.sans(14)).foregroundStyle(t.muted)
        }
    }

    private struct Pos { let name: Int; let surah: Int; let ayah: Int }

    private static func parse(_ key: String) -> Pos? {
        let p = key.split(separator: ":").compactMap { Int($0) }
        return p.count == 3 ? Pos(name: p[0], surah: p[1], ayah: p[2]) : nil
    }

    private func positionRow(_ t: Theme, _ p: Pos) -> some View {
        let name = NamesRepo.shared.card(p.name)?.name ?? ""
        return HStack(spacing: 12) {
            Button {
                nav.tab = 0
                nav.open(.name(p.name, tab: .verses))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(AppFont.serif(22)).foregroundStyle(t.gold)
                    Text("\(Surahs.name(p.surah)) · الآية \(p.ayah)").font(AppFont.sans(14)).foregroundStyle(t.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            UnsaveButton(key: .position(name: p.name, surah: p.surah, ayah: p.ayah))
        }
        .padding(14)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
    }
}

/// A saved sunnah: its «السبب ← النتيجة» line (loaded from the sunan pack) and where it comes from.
private struct SavedSunnahRow: View {
    let fp: String
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var easy: String?
    @State private var ref: String?
    @State private var stateId: Int?

    var body: some View {
        let t = Theme(scheme)
        HStack(spacing: 12) {
            Button {
                nav.tab = 0
                nav.open(.item(fp: fp, stateId: stateId))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(easy ?? "…").font(AppFont.sans(16, .medium)).foregroundStyle(t.cream)
                        .multilineTextAlignment(.leading).lineSpacing(4)
                    if let ref { Text(ref).font(AppFont.sans(13)).foregroundStyle(t.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            UnsaveButton(key: .sunnah(fp))
        }
        .padding(14)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
        .task(id: fp) {
            guard easy == nil, let v = try? await SunanStore.shared.item(fp: fp) else { return }
            easy = v.item.easy
            ref = v.item.ref
            stateId = v.item.stateId
        }
    }
}

/// ♥ that removes an item from «محفوظاتي».
private struct UnsaveButton: View {
    let key: SavedKey
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Button {
            Task { await SavedStore.shared.set(key, on: false) }
        } label: {
            Image(systemName: "heart.fill").font(.system(size: 18)).foregroundStyle(Theme(scheme).gold)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("إزالة من محفوظاتي")
    }
}
