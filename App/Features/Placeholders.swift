import SwiftUI

// Temporary screens — replaced section by section (names: Features/Names; sunan will mirror the website's «/sunan»).

struct SunanHomeView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        List(Content.sunan()?.domains ?? []) { d in
            Text(d.title).font(AppFont.serif(18)).foregroundStyle(t.cream)
                .listRowBackground(t.surface)
        }
        .scrollContentBackground(.hidden)
        .background(t.bg)
        .navigationTitle("سر علم السنن والأسباب")
    }
}

struct SavedView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 10) {
            Image(systemName: "bookmark").font(.system(size: 40)).foregroundStyle(t.gold)
            Text("لم تحفظ شيئًا بعد").font(AppFont.serif(22)).foregroundStyle(t.cream)
            Text("اضغط علامة الحفظ في أي اسم أو آية أو سنّة لتجدها هنا.")
                .font(AppFont.sans(15)).foregroundStyle(t.muted).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.bg.ignoresSafeArea())
        .navigationTitle("محفوظاتي")
    }
}

struct MoreView: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let t = Theme(scheme)
        List {
            Section("المحتوى") {
                LabeledContent("الأسماء", value: "\(Num.fmt(Content.names()?.names.count ?? 0)) اسمًا")
                LabeledContent("السنن والأسباب", value: "\(Num.fmt(Content.sunan()?.stats.items ?? 0)) سنّة")
            }
            .listRowBackground(t.surface)
            Section {
                Text("الإصدار 1.0").font(AppFont.sans(13)).foregroundStyle(t.muted)
            }
            .listRowBackground(t.surface)
        }
        .font(AppFont.sans(17))
        .scrollContentBackground(.hidden)
        .background(t.bg)
        .navigationTitle("المزيد")
    }
}
