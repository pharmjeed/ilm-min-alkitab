import SwiftUI

/// «محفوظاتي». Saving needs the (optional) account — owner's rule: nothing is saved on the device alone.
/// Signed out: how saving works and a sign-in button. Signed in: the owner's collections («مجموعاتي»,
/// 2026-11-24), then everything saved by kind: names, situations, sunan states, verses, sunan.
struct SavedView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var signingIn = false
    @State private var naming = false
    @State private var newTitle = ""

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
        .navigationDestination(for: CollectionRoute.self) { CollectionView(id: $0.id) }
        .task {
            if account.isSignedIn && store.phase == .idle { await store.reload() }
        }
        .sheet(isPresented: $signingIn) { SaveSignInSheet(item: nil) }
        .alert("مجموعة جديدة", isPresented: $naming) {
            TextField("اسم المجموعة", text: $newTitle)
            Button("أنشئ") {
                let title = newTitle
                newTitle = ""
                Task { _ = await store.createCollection(title) }
            }
            Button("إلغاء", role: .cancel) { newTitle = "" }
        } message: {
            Text("مثل: أدعية الصباح، أسماء الرحمة، سنن الرزق.")
        }
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
                step(t, "heart", "اضغط «احفظ» على أي اسم أو حالة أو آية أو سنّة.")
                step(t, "person.crop.circle", "سجّل الدخول بـ«آبل» أو «قوقل».")
                step(t, "folder", "رتّب ما حفظته في مجموعاتك، وتجده هنا.")
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
            if store.isEmpty && store.collections.isEmpty && store.phase != .ready {
                if store.phase == .failed {
                    VStack(spacing: 12) {
                        Text("تعذّر تحميل محفوظاتك.").font(AppFont.sans(16)).foregroundStyle(t.muted)
                        Button("حاول مرة أخرى") { Task { await store.reload() } }
                            .font(AppFont.sans(16, .medium)).foregroundStyle(t.gold)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    ProgressView().tint(t.gold).frame(maxWidth: .infinity).padding(.top, 40)
                }
            } else {
                collectionsBlock(t, store)

                if store.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "heart").font(.system(size: 32)).foregroundStyle(t.gold)
                        Text("لم تحفظ شيئًا بعد").font(AppFont.serif(22)).foregroundStyle(t.cream)
                        Text("اضغط «احفظ» على أي اسم أو حالة أو آية أو سنّة، فتجدها هنا.")
                            .font(AppFont.sans(15)).foregroundStyle(t.muted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 24)
                }
                kindSection(t, "الأسماء", store.names)
                kindSection(t, "الحالات", store.situations)
                kindSection(t, "أحوال السنن", store.states)
                kindSection(t, "من القرآن", store.positions)
                kindSection(t, "من السنن", store.sunan)
            }
        }
    }

    private func collectionsBlock(_ t: Theme, _ store: SavedStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("مجموعاتي").font(AppFont.serif(24)).foregroundStyle(t.cream)
                Spacer()
                Button { naming = true } label: {
                    Label("مجموعة جديدة", systemImage: "plus").font(AppFont.sans(15, .medium)).foregroundStyle(t.gold)
                }
                .buttonStyle(.plain)
            }
            if store.collections.isEmpty {
                Text("أنشئ مجموعة لتجمع فيها ما تحفظه كما تحب، ثم اختر المجموعة عند الحفظ.")
                    .font(AppFont.sans(14)).foregroundStyle(t.muted).lineSpacing(4)
                    .multilineTextAlignment(.leading)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(store.collections) { c in
                        NavigationLink(value: CollectionRoute(id: c.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "folder.fill").foregroundStyle(t.gold)
                                Text(c.title).font(AppFont.sans(16, .bold)).foregroundStyle(t.cream)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                Text(c.items.isEmpty ? "فارغة" : Arabic.count(c.items.count, Self.itemsForms))
                                    .font(AppFont.sans(13)).foregroundStyle(t.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                            .padding(14)
                            .background(t.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.gold.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    static let itemsForms = Arabic.CountForms(one: "عنصر واحد", two: "عنصران", few: "عناصر", many: "عنصرًا")

    @ViewBuilder
    private func kindSection(_ t: Theme, _ title: String, _ keys: [SavedKey]) -> some View {
        if !keys.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(AppFont.serif(22)).foregroundStyle(t.cream)
                Spacer()
                Text(Num.fmt(keys.count)).font(AppFont.sans(14)).foregroundStyle(t.muted)
            }
            .padding(.top, 8)
            LazyVStack(spacing: 8) {
                ForEach(keys, id: \.self) { k in SavedItemRow(key: k) }
            }
        }
    }
}

struct CollectionRoute: Hashable { let id: String }

/// One collection: its items, newest first; rename or delete it from the menu.
struct CollectionView: View {
    let id: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var confirmDelete = false
    @State private var title = ""

    var body: some View {
        let t = Theme(scheme)
        let store = SavedStore.shared
        let c = store.collections.first { $0.id == id }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let c {
                    if c.items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder").font(.system(size: 32)).foregroundStyle(t.gold)
                            Text("المجموعة فارغة").font(AppFont.serif(22)).foregroundStyle(t.cream)
                            Text("اضغط «احفظ» على أي اسم أو حالة أو آية أو سنّة، ثم اختر هذه المجموعة.")
                                .font(AppFont.sans(15)).foregroundStyle(t.muted).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(c.items, id: \.self) { k in SavedItemRow(key: k, inCollection: c.id) }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(t.bg.ignoresSafeArea())
        .navigationTitle(c?.title ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { title = c?.title ?? ""; renaming = true } label: { Label("إعادة التسمية", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("حذف المجموعة", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(t.gold)
                }
            }
        }
        .alert("إعادة التسمية", isPresented: $renaming) {
            TextField("اسم المجموعة", text: $title)
            Button("حفظ") { let v = title; Task { await store.renameCollection(id, to: v) } }
            Button("إلغاء", role: .cancel) {}
        }
        .confirmationDialog("حذف المجموعة", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("احذف المجموعة", role: .destructive) {
                Task {
                    if await store.deleteCollection(id) { dismiss() }
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("تُحذف المجموعة وحدها، وما فيها يبقى في «محفوظاتي».")
        }
    }
}

/// One saved item: its title and where it comes from; tapping opens it in «الرئيسية».
/// In a collection, the trailing button takes it out of the collection; elsewhere it removes it from «محفوظاتي».
struct SavedItemRow: View {
    let key: SavedKey
    var inCollection: String? = nil
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var nav: AppNav
    @State private var loaded: (title: String, sub: String, stateId: Int?)?

    var body: some View {
        let t = Theme(scheme)
        let info = describe()
        HStack(spacing: 12) {
            Button { open() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title).font(info.serif ? AppFont.serif(21) : AppFont.sans(16, .medium))
                        .foregroundStyle(info.serif ? t.gold : t.cream)
                        .multilineTextAlignment(.leading).lineSpacing(4)
                    if !info.sub.isEmpty {
                        Text(info.sub).font(AppFont.sans(13)).foregroundStyle(t.muted).multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                Task {
                    if let inCollection {
                        await SavedStore.shared.collect(key, in: inCollection, on: false)
                    } else {
                        await SavedStore.shared.set(key, on: false)
                    }
                }
            } label: {
                Image(systemName: inCollection == nil ? "heart.fill" : "minus.circle")
                    .font(.system(size: 18)).foregroundStyle(t.gold)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(inCollection == nil ? "إزالة من محفوظاتي" : "إخراج من المجموعة")
        }
        .padding(14)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 1))
        .task(id: key) {
            guard case .sunnah(let fp) = key, loaded == nil,
                  let v = try? await SunanStore.shared.item(fp: fp) else { return }
            loaded = (v.item.easy, v.item.ref, v.item.stateId)
        }
    }

    private func describe() -> (title: String, sub: String, serif: Bool) {
        let names = NamesRepo.shared
        switch key {
        case .name(let id):
            return (names.card(id)?.name ?? "", "من الأسماء الحسنى", true)
        case .situation(let id):
            guard let s = names.situation(id) else { return ("", "", false) }
            return (s.situation.isEmpty ? s.label : s.situation, names.door(s.doorId)?.label ?? "", false)
        case .state(let id):
            let sunan = SunanRepo.shared
            guard let s = sunan.state(id) else { return ("", "", false) }
            return (s.title, sunan.need(s.needId)?.title ?? "", false)
        case .position(let n, let s, let a):
            return (names.card(n)?.name ?? "", "\(Surahs.name(s)) · الآية \(a)", true)
        case .sunnah:
            return (loaded?.title ?? "…", loaded?.sub ?? "", false)
        }
    }

    private func open() {
        nav.tab = 0
        switch key {
        case .name(let id): nav.open(.name(id))
        case .situation(let id): nav.open(.situation(id))
        case .state(let id): nav.open(SunanRoute.state(id))
        case .position(let n, _, _): nav.open(.name(n, tab: .verses))
        case .sunnah(let fp): nav.open(.item(fp: fp, stateId: loaded?.stateId))
        }
    }
}
