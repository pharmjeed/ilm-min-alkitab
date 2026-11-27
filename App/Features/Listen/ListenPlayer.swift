import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

/// «مشغّل الصوت» (owner 2026-11-27): plays the tracks of `ListenPlan` one after another over the whole section — the
/// phone's voice for the words, Alafasy's recitation for the ayat — and goes on in the background and on the lock
/// screen, where «السابق» / «التالي» move by track. It remembers where it stopped.
@MainActor
final class ListenPlayer: NSObject, ObservableObject {
    static let shared = ListenPlayer()

    @Published private(set) var playing = false
    /// A session was started (the bar above the tabs shows).
    @Published private(set) var active = false
    @Published private(set) var track: ListenTrack?
    @Published private(set) var cursor: ListenCursor?
    @Published private(set) var trackCount = 0
    /// Fetching an ayah's recitation.
    @Published private(set) var waiting = false
    /// A recitation could not be fetched (no internet): it was skipped.
    @Published var notice: String?

    private var tracks: [ListenTrack] = []
    private var part = 0
    private var ayahs: [(Int, Int)] = []
    private var current: Kind = .none
    /// Bumped on every jump, so a callback of what was playing before is ignored.
    private var generation = 0
    private let synth = AVSpeechSynthesizer()
    private var audio: AVAudioPlayer?
    private var commandsReady = false
    private static let cursorKey = "listen.cursor"

    private enum Kind { case none, speech, recitation }

    override init() {
        super.init()
        synth.delegate = self
        synth.usesApplicationAudioSession = true
    }

    /// Where the reader stopped last time.
    static var saved: ListenCursor? {
        guard let d = UserDefaults.standard.data(forKey: cursorKey) else { return nil }
        return try? JSONDecoder().decode(ListenCursor.self, from: d)
    }

    // MARK: starting

    func start(_ c: ListenCursor) async {
        prepareSession()
        active = true
        await load(c.section, c.unit, track: c.track)
    }

    /// From a name's page: the name from its first track.
    func startName(_ id: Int) async {
        guard let u = ListenPlan.nameUnit(id) else { return }
        await start(ListenCursor(section: .names, unit: u, track: 0))
    }

    /// From a sunnah's page: its state, at this sunnah.
    func startSunnah(fp: String, stateId: Int) async {
        guard let u = ListenPlan.stateUnit(stateId) else { return }
        prepareSession()
        active = true
        let list = await ListenPlan.tracks(.sunan, u)
        let view = try? await SunanStore.shared.item(fp: fp, stateHint: stateId)
        let fpTitle = view.map { SunanText.easyParts($0.item.easy).cause }
        let i = list.firstIndex { $0.title == fpTitle } ?? 0
        setUnit(.sunan, u, list)
        play(track: i)
    }

    private func load(_ section: ListenSection, _ unit: Int, track: Int) async {
        var u = unit
        var list: [ListenTrack] = []
        let n = ListenPlan.unitCount(section)
        // a unit without tracks (not loaded): the next one
        while u < n {
            list = await ListenPlan.tracks(section, u)
            if !list.isEmpty { break }
            u += 1
        }
        guard !list.isEmpty else { stop(); return }
        setUnit(section, u, list)
        play(track: track < 0 ? list.count - 1 : min(track, list.count - 1))
    }

    private func setUnit(_ section: ListenSection, _ unit: Int, _ list: [ListenTrack]) {
        tracks = list
        trackCount = list.count
        cursor = ListenCursor(section: section, unit: unit, track: 0)
    }

    // MARK: moving

    func next() {
        guard let c = cursor else { return }
        if c.track + 1 < tracks.count { play(track: c.track + 1); return }
        Task { await nextUnit() }
    }

    func previous() {
        guard let c = cursor else { return }
        if c.track > 0 { play(track: c.track - 1); return }
        Task { await previousUnit(atEnd: true) }
    }

    func nextUnit() async {
        guard let c = cursor else { return }
        if c.unit + 1 >= ListenPlan.unitCount(c.section) { stop(); return }
        haltSound()
        await load(c.section, c.unit + 1, track: 0)
    }

    func previousUnit(atEnd: Bool = false) async {
        guard let c = cursor, c.unit > 0 else { return }
        haltSound()
        await load(c.section, c.unit - 1, track: atEnd ? -1 : 0)
    }

    func toggle() { playing ? pause() : resume() }

    func pause() {
        switch current {
        case .speech: synth.pauseSpeaking(at: .word)
        case .recitation: audio?.pause()
        case .none: break
        }
        playing = false
        publish()
    }

    func resume() {
        guard active else {
            if let c = Self.saved { Task { await start(c) } }
            return
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        switch current {
        case .speech: synth.continueSpeaking()
        case .recitation: audio?.play()
        case .none: if let c = cursor { play(track: c.track) }
        }
        playing = true
        publish()
    }

    func stop() {
        haltSound()
        playing = false
        active = false
        track = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: playing

    private func play(track i: Int) {
        guard tracks.indices.contains(i), var c = cursor else { return }
        haltSound()
        c.track = i
        cursor = c
        track = tracks[i]
        part = 0
        playing = true
        if let data = try? JSONEncoder().encode(c) { UserDefaults.standard.set(data, forKey: Self.cursorKey) }
        prefetch(from: i)
        publish()
        playPart(generation)
    }

    private func haltSound() {
        generation += 1
        current = .none
        ayahs = []
        waiting = false
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        audio?.stop()
        audio = nil
    }

    private func playPart(_ gen: Int) {
        guard gen == generation, let t = track else { return }
        guard part < t.parts.count else { next(); return }
        switch t.parts[part] {
        case .say(let text):
            current = .speech
            let u = AVSpeechUtterance(string: text)
            u.voice = Self.voice
            u.rate = AVSpeechUtteranceDefaultSpeechRate
            u.postUtteranceDelay = 0.25
            synth.speak(u)
            if !playing { synth.pauseSpeaking(at: .immediate) }
        case .ayat(let s, let from, let to):
            ayahs = (from...max(from, to)).map { (s, $0) }
            playAyah(gen)
        }
    }

    private func partDone(_ gen: Int) {
        guard gen == generation else { return }
        part += 1
        playPart(gen)
    }

    private func playAyah(_ gen: Int) {
        guard gen == generation else { return }
        guard !ayahs.isEmpty else { partDone(gen); return }
        let (s, a) = ayahs.removeFirst()
        current = .recitation
        Task {
            if !Recitations.has(s, a) { waiting = true }
            let url = await Recitations.file(s, a)
            guard gen == generation else { return }
            waiting = false
            guard let url, let player = try? AVAudioPlayer(contentsOf: url) else {
                notice = "تعذّر تحميل تلاوة آية دون إنترنت، فتُخطّيت."
                playAyah(gen)
                return
            }
            player.delegate = self
            audio = player
            if playing { player.play() }
        }
    }

    /// The ayat of this track and the next two, fetched ahead.
    private func prefetch(from i: Int) {
        let list = tracks[i..<min(i + 3, tracks.count)].flatMap(\.ayat)
        Task.detached(priority: .utility) {
            for (s, a) in list where !Recitations.has(s, a) { _ = await Recitations.file(s, a) }
        }
    }

    private static var voice: AVSpeechSynthesisVoice? {
        let ar = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
        return ar.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "ar-SA")
    }

    // MARK: the system

    private func prepareSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio)
        try? s.setActive(true)
        guard !commandsReady else { return }
        commandsReady = true
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        cc.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        cc.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        cc.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                               queue: .main) { [weak self] n in
            let began = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in if began { self?.pause() } }
        }
    }

    /// The lock screen's player: the name or the sunnah, its position, and «علم من الكتاب».
    private func publish() {
        guard let t = track else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: t.subtitle,
            MPMediaItemPropertyAlbumTitle: "علم من الكتاب",
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        if let c = cursor {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = c.track
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = tracks.count
        }
        if let art = Self.artwork(t.title) { info[MPMediaItemPropertyArtwork] = art }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static var artCache: [String: MPMediaItemArtwork] = [:]

    private static func artwork(_ title: String) -> MPMediaItemArtwork? {
        if let a = artCache[title] { return a }
        let r = ImageRenderer(content: ListenArtwork(title: title))
        r.scale = 2
        guard let img = r.uiImage else { return nil }
        let art = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        if artCache.count > 30 { artCache.removeAll() }
        artCache[title] = art
        return art
    }
}

extension ListenPlayer: AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.current == .speech else { return }
            self.partDone(self.generation)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.audio else { return }
            self.playAyah(self.generation)
        }
    }
}

/// The square on the lock screen's player: the name (or the sunnah) in gold on the night colour.
struct ListenArtwork: View {
    let title: String
    var body: some View {
        ZStack {
            WidgetLook.night
            Text(title)
                .font(WidgetLook.serif(title.count > 24 ? 28 : 44)).foregroundStyle(WidgetLook.gold)
                .multilineTextAlignment(.center).lineLimit(4).minimumScaleFactor(0.5)
                .padding(24)
        }
        .frame(width: 300, height: 300)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
